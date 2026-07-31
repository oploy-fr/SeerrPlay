#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/standard_method_codec.h>

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  window_control_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "app.seerrplay/window",
          &flutter::StandardMethodCodec::GetInstance());
  window_control_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "isFullscreen") {
          result->Success(flutter::EncodableValue(is_fullscreen_));
          return;
        }
        if (call.method_name() == "toggleFullscreen") {
          SetFullscreen(!is_fullscreen_);
          result->Success(flutter::EncodableValue(is_fullscreen_));
          return;
        }
        result->NotImplemented();
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  window_control_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::SetFullscreen(bool fullscreen) {
  HWND window = GetHandle();
  if (window == nullptr || fullscreen == is_fullscreen_) {
    return;
  }

  if (fullscreen) {
    windowed_style_ = GetWindowLongPtr(window, GWL_STYLE);
    GetWindowPlacement(window, &windowed_placement_);
    MONITORINFO monitor_info = {sizeof(MONITORINFO)};
    GetMonitorInfo(MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST),
                   &monitor_info);
    SetWindowLongPtr(window, GWL_STYLE,
                     windowed_style_ & ~WS_OVERLAPPEDWINDOW);
    SetWindowPos(window, HWND_TOP, monitor_info.rcMonitor.left,
                 monitor_info.rcMonitor.top,
                 monitor_info.rcMonitor.right - monitor_info.rcMonitor.left,
                 monitor_info.rcMonitor.bottom - monitor_info.rcMonitor.top,
                 SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
  } else {
    SetWindowLongPtr(window, GWL_STYLE, windowed_style_);
    SetWindowPlacement(window, &windowed_placement_);
    SetWindowPos(window, nullptr, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER |
                     SWP_FRAMECHANGED);
  }
  is_fullscreen_ = fullscreen;
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
