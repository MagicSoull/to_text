# Голосовая диктовка в текст (Voice-to-Text Dictation)

Скрипт для **real-time** голосовой диктовки через [whisper.cpp](https://github.com/ggml-org/whisper.cpp) на Wayland (GNOME).

## Как работает

- **Хоткей** → начинает запись и непрерывную транскрипцию
- Пока говорите — текст **сам печатается** в активное окно и **копируется в буфер обмена**
- **Хоткей снова** → добивается последняя фраза, финальный текст в буфере
- Можно переключать окна во время диктовки — текст идёт туда, где фокус

## Требования

```bash
sudo pacman -S wtype wl-clipboard libnotify pulseaudio-utils
```

- **whisper.cpp** — собранный с `whisper-stream` и `whisper-cli`
- **parec** (pulseaudio-utils / pipewire-pulse) — запись микрофона (не используется, но whisper-stream зависит от SDL2/ALSA/PipeWire)
- **wtype** — эмуляция клавиатуры на Wayland
- **wl-clipboard** — буфер обмена
- **libnotify** — уведомления

## Установка

### 1. Сборка whisper.cpp

```bash
git clone https://github.com/ggml-org/whisper.cpp.git ~/whisper.cpp
cd ~/whisper.cpp
cmake -B build -DWHISPER_SDL2=ON
cmake --build build --config Release -j
```

### 2. Скачать модель

```bash
bash models/download-ggml-model.sh large-v3-turbo-q5_0
```

Или через curl:

```bash
curl -L -o models/ggml-large-v3-turbo-q5_0.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin
```

### 3. Скопировать и настроить скрипт

```bash
cp whisper-dictation.sh ~/whisper.cpp/
chmod +x ~/whisper.cpp/whisper-dictation.sh
```

Отредактируйте переменные в начале файла:

| Переменная | По умолчанию | Описание |
|---|---|---|
| `WHISPER_STREAM` | `~/whisper.cpp/build/bin/whisper-stream` | Путь к whisper-stream |
| `MODEL` | `~/whisper.cpp/models/ggml-large-v3-turbo-q5_0.bin` | Путь к модели |
| `LANGUAGE` | `ru` | Язык распознавания |
| `THREADS` | `8` | Число потоков CPU |

### 4. Настроить хоткей

**GUI:** Настройки → Клавиатура → Сочетания клавиш → Пользовательские сочетания → Добавить

- Имя: `Dictation`
- Команда: полный путь к `whisper-dictation.sh`, например `/home/user/whisper.cpp/whisper-dictation.sh`
- Сочетание: например `Super+B` или `Ctrl+Super+V`

**Терминал:**

```bash
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
  "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybindings:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ \
  name 'Dictation'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybindings:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ \
  command '/home/user/whisper.cpp/whisper-dictation.sh'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybindings:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ \
  binding '<Super>b'
```

## Использование

1. **Хоткей** → уведомление **"Recording…"**
2. Говорите в микрофон
3. Через несколько секунд (первый инференс на CPU) текст начинает появляться в активном окне
4. Каждые ~3-6 секунд допечатываются новые слова, буфер обмена обновляется автоматически
5. Можно переключить окно — текст продолжит печататься в новом
6. **Хоткей снова** → уведомление **"Transcribing…"** → завершающая фраза → финальный текст в буфере
7. Если текст не напечатался — просто `Ctrl+V` в любом месте

## Возможные проблемы

| Проблема | Решение |
|---|---|
| "No speech detected" | Проверьте микрофон: `parec --list-devices` |
| Очень долгая транскрипция | Используйте `small-q5_1` модель |
| Текст не печатается | Нажмите Ctrl+V — текст в буфере |
| Не запускается запись | Установите `pulseaudio-utils` и `libsdl2` |

## Как это устроено внутри

1. `whisper-stream` транскрибирует аудио в реальном времени (скользящее окно 10 сек, шаг 3 сек)
2. Фоновый монитор через `tail -f --pid` ловит новые строки из выходного файла
3. Для каждой строки вычисляется **дельта** — только новые слова (не перекрывающиеся с предыдущей строкой)
4. Дельта печатается через `wtype`, полный текст копируется в `wl-copy`
5. При остановке процесс убивается, монитор выходит сам (`tail --pid` детектит смерть), финальный clipboard
