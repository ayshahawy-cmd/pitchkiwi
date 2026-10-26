# Third-party notices

PitchKiwi ships the following open-source components. Keep this file and the complete notices in `Legal/` with redistributed builds. The app builder copies these into `PitchKiwi.app/Contents/Resources/Legal/` before signing the bundle.

## whisper.cpp

- Project: [ggml-org/whisper.cpp](https://github.com/ggml-org/whisper.cpp)
- Bundled artifact: `whisper.xcframework`, release build b5130 / v1.9.4 source revision `927cfce34f31707e17f2bff35c349632fb9e2c3a`
- License: MIT
- Copyright © 2023-2026 The ggml authors
- Complete upstream notice: [Legal/whisper.cpp-LICENSE.txt](Legal/whisper.cpp-LICENSE.txt)
- Framework archive SHA-256: `033a43b0174e8cf9b366f72e4a428cdcf126f93ad1c87d3fa119a96bed6f231a`

## Whisper model and architecture

- Project: [openai/whisper](https://github.com/openai/whisper)
- Bundled default model: `ggml-base.en.bin`, converted for whisper.cpp
- License: MIT
- Copyright © 2022 OpenAI
- Model source: [ggerganov/whisper.cpp on Hugging Face](https://huggingface.co/ggerganov/whisper.cpp)
- Complete upstream notice: [Legal/whisper-LICENSE.txt](Legal/whisper-LICENSE.txt)
- Default model SHA-256: `a03779c86df3323075f5e796cb2ce5029f00ec8869eee3fdfb897afe36c6d002`

## Platform frameworks and assets

SwiftUI, AppKit, AVFoundation, ApplicationServices, CryptoKit, and system fonts are provided by Apple under its platform terms; they are not relicensed by PitchKiwi. The source package has no downloaded Swift package dependencies. PitchKiwi's original SVG artwork and repository documentation are covered by the repository MIT license. Third-party product names in examples do not imply endorsement or transfer rights to their branding. Imported models remain subject to their own licenses.

## MIT license text

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
