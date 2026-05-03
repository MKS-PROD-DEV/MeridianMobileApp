/*
  Injected JavaScript that provides the SCORM runtime bridge.
  - implementing the SCORM API methods used by offline content
  - exposing LMS-style APIs such as:
    - `LMSInitialize`
    - `LMSFinish`
    - `LMSCommit`
    - `LMSGetValue`
    - `LMSSetValue`
  - loading saved learner state from native storage
  - saving updated learner state back to native storage
  - installing the API across frames/windows
  - auto-persisting progress periodically
  This is the layer that allows offline SCORM content to function correctly without an LMS backend.
*/
import Foundation

enum ScormAPIShim {

  static func javascript(assetId: String, scoId: String) -> String {
    return """
      (function() {
        if (window.__offlineScormShimInstalled) return;
        window.__offlineScormShimInstalled = true;

        var __cmi = null;
        var __dirty = false;
        var __lastError = "0";
        var __initialized = false;
        var __finished = false;
        var __initializedAt = null;

        function __nowMs() { return Date.now(); }
        function __pad2(n){ n = Math.floor(Math.max(0, n)); return (n < 10 ? "0" + n : "" + n); }

        function __parseTimeToSeconds(hhmmss) {
          if (!hhmmss || typeof hhmmss !== "string") return 0;
          var m = hhmmss.match(/^(\\d+):(\\d{2}):(\\d{2})(?:\\.(\\d+))?$/);
          if (!m) return 0;
          var h = parseInt(m[1], 10) || 0;
          var mi = parseInt(m[2], 10) || 0;
          var s = parseInt(m[3], 10) || 0;
          return h * 3600 + mi * 60 + s;
        }

        function __formatSecondsToTime(totalSeconds) {
          totalSeconds = Math.max(0, Math.floor(totalSeconds));
          var h = Math.floor(totalSeconds / 3600);
          var m = Math.floor((totalSeconds % 3600) / 60);
          var s = totalSeconds % 60;
          return __pad2(h) + ":" + __pad2(m) + ":" + __pad2(s);
        }

        function __defaultCmi() {
          return {
            "cmi.core.student_id": "offline",
            "cmi.core.student_name": "Offline Learner",
            "cmi.core.lesson_location": "",
            "cmi.core.lesson_status": "not attempted",
            "cmi.core.credit": "credit",
            "cmi.core.entry": "",
            "cmi.core.exit": "",
            "cmi.core.lesson_mode": "normal",
            "cmi.core.score.raw": "",
            "cmi.core.score.min": "",
            "cmi.core.score.max": "",
            "cmi.core.total_time": "00:00:00",
            "cmi.core.session_time": "00:00:00",
            "cmi.suspend_data": "",
            "cmi.launch_data": "",
            "cmi.comments": "",
            "cmi.comments_from_lms": "",
            "cmi.student_data.mastery_score": "",
            "cmi.student_data.max_time_allowed": "",
            "cmi.student_data.time_limit_action": "",
            "cmi.student_preference.audio": "0",
            "cmi.student_preference.language": "",
            "cmi.student_preference.speed": "0",
            "cmi.student_preference.text": "0"
          };
        }

        function __ensureLoaded() {
          if (__cmi) return;
          __cmi = __defaultCmi();
          try {
            window.webkit &&
            window.webkit.messageHandlers &&
            window.webkit.messageHandlers.scormStore &&
            window.webkit.messageHandlers.scormStore.postMessage({
              op: "load",
              assetId: "\(assetId)",
              scoId: "\(scoId)"
            });
          } catch (e) {}
        }

        window.__scormNativeStoreLoad = function(obj) {
          try {
            if (obj && typeof obj === "object") {
              __cmi = Object.assign(__defaultCmi(), obj);
            } else {
              __cmi = __defaultCmi();
            }
          } catch (e) {
            __cmi = __defaultCmi();
          }
        };

        function __saveToNative() {
          if (!__dirty || !__cmi) return;
          __dirty = false;
          try {
            window.webkit &&
            window.webkit.messageHandlers &&
            window.webkit.messageHandlers.scormStore &&
            window.webkit.messageHandlers.scormStore.postMessage({
              op: "save",
              assetId: "\(assetId)",
              scoId: "\(scoId)",
              cmi: __cmi
            });
          } catch (e) {}
        }

        function __ok() { __lastError = "0"; return "true"; }
        function __fail(code) { __lastError = String(code || "101"); return "false"; }

        function __get(k) {
          __ensureLoaded();
          if (!k) return "";
          var v = __cmi[k];
          return (v === undefined || v === null) ? "" : String(v);
        }

        function __set(k, v) {
          __ensureLoaded();
          if (!k) return __fail("201");
          if (k === "cmi.core.total_time") return __fail("403");
          __cmi[k] = (v === undefined || v === null) ? "" : String(v);
          __dirty = true;
          return __ok();
        }

        function __commit() {
          __ensureLoaded();

          var session = __parseTimeToSeconds(__get("cmi.core.session_time"));
          if (session > 0) {
            var total = __parseTimeToSeconds(__get("cmi.core.total_time"));
            __cmi["cmi.core.total_time"] = __formatSecondsToTime(total + session);
            __cmi["cmi.core.session_time"] = "00:00:00";
            __dirty = true;
          }

          __saveToNative();
          return __ok();
        }

        var API = {
          LMSInitialize: function(_) {
            __ensureLoaded();
            __initialized = true;
            __finished = false;
            __initializedAt = __nowMs();
            return __ok();
          },

          LMSFinish: function(_) {
            if (__initializedAt) {
              var elapsedSec = Math.floor((__nowMs() - __initializedAt) / 1000);
              var st = __get("cmi.core.session_time");
              if (!st || st === "00:00:00") {
                __cmi["cmi.core.session_time"] = __formatSecondsToTime(elapsedSec);
                __dirty = true;
              }
            }
            __finished = true;
            return __commit();
          },

          LMSCommit: function(_) {
            return __commit();
          },

          LMSGetValue: function(k) {
            return __get(k);
          },

          LMSSetValue: function(k, v) {
            return __set(k, v);
          },

          LMSGetLastError: function() {
            return __lastError;
          },

          LMSGetErrorString: function(code) {
            return "SCORM error " + code;
          },

          LMSGetDiagnostic: function(code) {
            return "SCORM diagnostic " + code;
          }
        };

        function __installApiOn(win) {
          if (!win) return;
          try { win.API = API; } catch (e) {}
          try { win.API_1484_11 = undefined; } catch (e) {}
        }

        function __walkAndInstall(win, depth) {
          if (!win || depth > 10) return;
          __installApiOn(win);
          try {
            for (var i = 0; i < win.frames.length; i++) {
              __walkAndInstall(win.frames[i], depth + 1);
            }
          } catch (e) {}
        }

        function getAPI() {
          try {
            if (window.API) return window.API;
            if (window.parent && window.parent !== window && window.parent.API) return window.parent.API;
            if (window.top && window.top.API) return window.top.API;
            if (window.opener && window.opener.API) return window.opener.API;
          } catch (e) {}
          return API;
        }

        __walkAndInstall(window, 0);
        try { if (window.top) __walkAndInstall(window.top, 0); } catch (e) {}
        try { if (window.parent) __walkAndInstall(window.parent, 0); } catch (e) {}
        try { if (window.opener) __walkAndInstall(window.opener, 0); } catch (e) {}

        window.getAPI = getAPI;
        window.findAPI = getAPI;
        window.GetAPI = getAPI;
        window.GetAPIHandle = getAPI;
        window.getAPIHandle = getAPI;

        window.doInitialize = window.doLMSInitialize = function() {
          return getAPI().LMSInitialize("");
        };

        window.doTerminate = window.doLMSFinish = function() {
          return getAPI().LMSFinish("");
        };

        window.doCommit = window.doLMSCommit = function() {
          return getAPI().LMSCommit("");
        };

        window.doGetValue = window.doLMSGetValue = function(name) {
          return getAPI().LMSGetValue(name);
        };

        window.doSetValue = window.doLMSSetValue = function(name, value) {
          return getAPI().LMSSetValue(name, value);
        };

        window.doGetLastError = window.doLMSGetLastError = function() {
          return getAPI().LMSGetLastError();
        };

        window.doGetErrorString = window.doLMSGetErrorString = function(code) {
          return getAPI().LMSGetErrorString(code);
        };

        window.doGetDiagnostic = window.doLMSGetDiagnostic = function(code) {
          return getAPI().LMSGetDiagnostic(code);
        };

        setInterval(function() {
          try { __walkAndInstall(window, 0); } catch (e) {}
          try { if (window.top) __walkAndInstall(window.top, 0); } catch (e) {}
        }, 1000);

        setInterval(function() {
          try { __saveToNative(); } catch (e) {}
        }, 2000);

        window.addEventListener("pagehide", function() {
          try { __commit(); } catch (e) {}
        });
      })();
      """
  }
}
