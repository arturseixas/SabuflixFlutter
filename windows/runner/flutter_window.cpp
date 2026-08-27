#include "flutter_window.h"

#include <optional>
#include <variant>

#include "flutter/generated_plugin_registrant.h"

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
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  pip_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.sabuflix.app/native_pip",
          &flutter::StandardMethodCodec::GetInstance());
  pip_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "isSupported") {
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "enter") {
          EnterPictureInPicture();
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "exit") {
          ExitPictureInPicture();
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

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
  pip_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
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
    case WM_KEYDOWN:
      if (is_in_pip_ && wparam == VK_ESCAPE) {
        ExitPictureInPicture();
        return 0;
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::EnterPictureInPicture() {
  if (is_in_pip_) return;
  HWND window = GetHandle();
  if (!window) return;

  normal_placement_.length = sizeof(WINDOWPLACEMENT);
  GetWindowPlacement(window, &normal_placement_);
  ShowWindow(window, SW_RESTORE);
  const int width = 480;
  const int height = 300;
  RECT work_area{};
  SystemParametersInfo(SPI_GETWORKAREA, 0, &work_area, 0);
  SetWindowPos(window, HWND_TOPMOST, work_area.right - width - 20,
               work_area.bottom - height - 20, width, height,
               SWP_SHOWWINDOW | SWP_FRAMECHANGED);
  is_in_pip_ = true;
  NotifyPictureInPicture(true);
}

void FlutterWindow::ExitPictureInPicture() {
  if (!is_in_pip_) return;
  HWND window = GetHandle();
  if (!window) return;

  SetWindowPos(window, HWND_NOTOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
  SetWindowPlacement(window, &normal_placement_);
  is_in_pip_ = false;
  NotifyPictureInPicture(false);
}

void FlutterWindow::NotifyPictureInPicture(bool active) {
  if (pip_channel_) {
    pip_channel_->InvokeMethod(
        "pipChanged",
        std::make_unique<flutter::EncodableValue>(active));
  }
}
