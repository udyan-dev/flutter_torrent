#include "flutter_torrent.h"

#include <atomic>
#include <mutex>
#include <vector>

using std::string;

#define MEM_K 1024
#define MEM_K_STR "KiB"
#define MEM_M_STR "MiB"
#define MEM_G_STR "GiB"
#define MEM_T_STR "TiB"

#define DISK_K 1000
#define DISK_K_STR "kB"
#define DISK_M_STR "MB"
#define DISK_G_STR "GB"
#define DISK_T_STR "TB"

#define SPEED_K 1000
#define SPEED_K_STR "kB/s"
#define SPEED_M_STR "MB/s"
#define SPEED_G_STR "GB/s"
#define SPEED_T_STR "TB/s"

namespace {

enum class EngineState { INIT = 0, RUNNING = 1, SHUTTING_DOWN = 2, DEAD = 3 };

struct EngineLocalCB {
  std::string result;
  bool set = false;
};

static void engine_rpc_cb(tr_session * /*s*/, tr_variant *response, void *user_data) {
  if (response == nullptr || user_data == nullptr) {
    return;
  }
  EngineLocalCB *cb = reinterpret_cast<EngineLocalCB *>(user_data);
  cb->result = tr_variantToStr(response, TR_VARIANT_FMT_JSON);
  cb->set = true;
  tr_variantClear(response);
}

class Engine {
 public:
  static Engine &instance() {
    static Engine inst;
    return inst;
  }

  // Initialize the engine. Returns true on success.
  bool init(const char *config_dir, const char *app_name) {
    if (config_dir == nullptr || app_name == nullptr) {
      return false;
    }

    std::lock_guard<std::mutex> lk(lifecycle_mutex_);
    EngineState expected = EngineState::INIT;
    if (!state_.compare_exchange_strong(expected, EngineState::RUNNING)) {
      // If already running, treat as idempotent success. If shutting down or dead, fail.
      if (expected == EngineState::RUNNING) {
        return true;
      }
      return false;
    }

    // Safe copies of strings
    config_dir_ = std::string(config_dir);

    tr_formatter_mem_init(MEM_K, MEM_K_STR, MEM_M_STR, MEM_G_STR, MEM_T_STR);
    tr_formatter_size_init(DISK_K, DISK_K_STR, DISK_M_STR, DISK_G_STR,
                           DISK_T_STR);
    tr_formatter_speed_init(SPEED_K, SPEED_K_STR, SPEED_M_STR, SPEED_G_STR,
                            SPEED_T_STR);

    tr_variant settings;
    tr_variantInitDict(&settings, 0);
    tr_sessionLoadSettings(&settings, config_dir_.c_str(), app_name);

    session_ = tr_sessionInit(config_dir_.c_str(), false, &settings);
    if (session_ == nullptr) {
      tr_variantClear(&settings);
      state_.store(EngineState::DEAD);
      return false;
    }

    tr_ctor *ctor = tr_ctorNew(session_);
    tr_sessionLoadTorrents(session_, ctor);
    tr_ctorFree(ctor);

    tr_variantClear(&settings);
    return true;
  }

  void close() {
    EngineState prev = state_.exchange(EngineState::SHUTTING_DOWN);
    if (prev == EngineState::DEAD || prev == EngineState::INIT) {
      // nothing to do
      state_.store(EngineState::DEAD);
      return;
    }

    std::lock_guard<std::mutex> lk(lifecycle_mutex_);
    if (session_ != nullptr) {
      // save settings before closing
      tr_variant settings;
      tr_variantInitDict(&settings, 0);
      tr_sessionSaveSettings(session_, config_dir_.c_str(), &settings);
      tr_variantClear(&settings);

      tr_sessionClose(session_);
      session_ = nullptr;
    }

    state_.store(EngineState::DEAD);
  }

  bool is_running() const { return state_.load() == EngineState::RUNNING; }

  // Synchronous request - runs in caller thread to avoid creating threads here.
  // Returns empty string on error.
  std::string request_sync(const char *json_string) {
    if (json_string == nullptr) {
      return std::string();
    }

    if (!is_running() || session_ == nullptr) {
      return std::string();
    }

    // Build request variant from buffer. Validate input by checking length.
    try {
      tr_variant request;
      // Create a copy of the input into a safe std::string
      std::string json_copy(json_string);
      tr_variantFromBuf(&request, TR_VARIANT_PARSE_JSON, json_copy);

      EngineLocalCB local_cb;

      // Execute synchronously in caller thread. The callback will run before return.
      tr_rpc_request_exec_json(session_, &request, engine_rpc_cb, &local_cb);
      tr_variantClear(&request);

      if (!local_cb.set) {
        return std::string();
      }
      return local_cb.result;
    } catch (...) {
      // No exceptions escape to FFI boundary.
      return std::string();
    }
  }

  // Save and reset operations with safety checks.
  void save_settings() {
    if (!is_running() || session_ == nullptr) {
      return;
    }
    tr_variant settings;
    tr_variantInitDict(&settings, 0);
    tr_sessionSaveSettings(session_, config_dir_.c_str(), &settings);
    tr_variantClear(&settings);
  }

  void reset_settings() {
    if (!is_running() || session_ == nullptr) {
      return;
    }
    tr_variant default_settings;
    tr_variantInitDict(&default_settings, 0);
    tr_sessionGetDefaultSettings(&default_settings);
    tr_sessionSet(session_, &default_settings);
    tr_sessionSaveSettings(session_, config_dir_.c_str(), &default_settings);
    tr_variantClear(&default_settings);
  }

 private:
  Engine() : state_(EngineState::INIT), session_(nullptr) {}
  ~Engine() { close(); }

  std::atomic<EngineState> state_;
  tr_session *session_;
  std::string config_dir_;
  mutable std::mutex lifecycle_mutex_;
};

}  // namespace

// FFI functions: thin, validated wrappers that enforce lifecycle rules and input checks.

FFI_PLUGIN_EXPORT void init_session(char *config_dir, char *app_name) {
  if (config_dir == nullptr || app_name == nullptr) {
    return;
  }
  Engine::instance().init(config_dir, app_name);
}

FFI_PLUGIN_EXPORT void close_session() {
  Engine::instance().close();
}

FFI_PLUGIN_EXPORT char *request(char *json_string) {
  if (json_string == nullptr) {
    // Return an allocated empty JSON result to avoid returning null to Dart.
    const char *empty = "{\"result\":\"error\",\"arguments\":{}}";
    char *resp = new char[std::strlen(empty) + 1];
    std::strcpy(resp, empty);
    return resp;
  }

  std::string result = Engine::instance().request_sync(json_string);
  if (result.empty()) {
    const char *empty = "{\"result\":\"error\",\"arguments\":{}}";
    char *resp = new char[std::strlen(empty) + 1];
    std::strcpy(resp, empty);
    return resp;
  }

  char *resp = new char[result.length() + 1];
  std::strcpy(resp, result.c_str());
  return resp;
}

FFI_PLUGIN_EXPORT void free_response(char *resp) {
  if (resp == nullptr) {
    return;
  }
  // resp was allocated with new[] in `request`.
  try {
    delete[] resp;
  } catch (...) {
    // Never let exceptions escape to FFI boundary.
  }
}

FFI_PLUGIN_EXPORT void save_settings() {
  Engine::instance().save_settings();
}

FFI_PLUGIN_EXPORT void reset_settings() {
  Engine::instance().reset_settings();
}


