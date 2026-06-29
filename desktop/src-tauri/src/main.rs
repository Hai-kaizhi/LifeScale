// 发布模式下避免 Windows 额外打开控制台窗口，请勿移除。
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    lifescale_desktop_lib::run()
}
