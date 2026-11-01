# Validation / 验证范围

Release: v0.15.0 early preview.

- Local build: Apple Silicon, macOS 27.2, Swift 6.4.2 / Swift 5 language mode; deployment target macOS 14.
- Build, ad-hoc signing and strict signature verification passed.
- 57 core/geometry checks and 17 state/localization checks passed without live API requests.
- Earlier development builds were opened and inspected on this machine. Capsule/editor separation was checked using actual window coordinates. This does not cover every display configuration.
- The v0.15.0 capsule launched successfully. Automated Settings navigation failed with `noWindowsAvailable`; full English UI, floating hints and release animations have **not** completed end-to-end visual acceptance.
- Model IDs were checked against DeepSeek's public docs on November 1, 2026; account availability and actual model output quality were not validated.
- No provider key, private history, local configuration or user prompt is bundled. No telemetry or geometry tracing in the published build.
- No Developer ID signature, notarization, automatic updates, Intel build, or full minimum-OS matrix validation.

This is a preview to gather reproducible feedback, not a claim of complete production readiness.

本版完成本地编译、签名及 74 项检查。没有真实 API 全链路验证；英文界面与浮签尚未完成完整视觉验收。发布包未包含用户 Key、配置、历史或私人提示词。欢迎提供版本、系统、显示器信息和复现步骤。
