# Голосовая диктовка в текст (Voice-to-Text Dictation)

Скрипт для голосовой диктовки через [whisper.cpp](https://github.com/ggml-org/whisper.cpp) на Wayland (GNOME).

## Как работает

- Привязывается к глобальному хоткею в GNOME
- Первое нажатие — начинает запись с микрофона
- Второе нажатие — транскрибирует аудио и печатает текст в активное окно через `wtype`
- Текст также копируется в буфер обмена через `wl-copy`

## Требования

- **Arch Linux** (или любой дистрибутив с GNOME/Wayland)
- **whisper.cpp** — собранный с `whisper-cli`
- **parec** (pulseaudio-utils / pipewire-pulse) — запись с микрофона
- **wtype** — эмуляция ввода клавиатуры на Wayland
- **wl-clipboard** — буфер обмена
- **libnotify** — уведомления (notify-send)

Установка зависимостей:

```bash
sudo pacman -S wtype wl-clipboard libnotify pulseaudio-utils
```

## Установка

### 1. Сборка whisper.cpp

```bash
git clone https://github.com/ggml-org/whisper.cpp.git ~/whisper.cpp
cd ~/whisper.cpp
cmake -B build
cmake --build build --config Release -j
```

### 2. Скачать модель

```bash
bash models/download-ggml-model.sh large-v3-turbo-q5_0
```

Или через curl напрямую:

```bash
curl -L -o models/ggml-large-v3-turbo-q5_0.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin
```

Другие модели: `large-v3-turbo` (1.5 GB, точнее, но медленнее), `small-q5_1`, `medium-q5_0`.

### 3. Скопировать скрипт

```bash
cp whisper-dictation.sh ~/whisper.cpp/
chmod +x ~/whisper.cpp/whisper-dictation.sh
```

### 4. Настроить скрипт (если нужно)

В начале файла `~/whisper.cpp/whisper-dictation.sh`:

| Переменная | По умолчанию | Описание |
|---|---|---|
| `WHISPER_CLI` | `~/whisper.cpp/build/bin/whisper-cli` | Путь к whisper-cli |
| `MODEL` | `~/whisper.cpp/models/ggml-large-v3-turbo-q5_0.bin` | Путь к модели |
| `LANGUAGE` | `ru` | Язык распознавания |
| `THREADS` | `8` | Число потоков CPU |

### 5. Настроить хоткей

**Через GUI:** Настройки → Клавиатура → Сочетания клавиш → Пользовательские сочетания → Добавить

- Имя: `Dictation`
- Команда: `~/whisper.cpp/whisper-dictation.sh` (укажите полный путь, например `/home/user/whisper.cpp/whisper-dictation.sh`)
- Назначить сочетание (например, `Super+B` или `Ctrl+Super+V`)

**Через терминал:**

```bash
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
  "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybindings:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name 'Dictation'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybindings:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command '/home/void/whisper.cpp/whisper-dictation.sh'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybindings:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Super>b'
```

## Использование

1. Нажмите хоткей — появится уведомление **"Recording…"**
2. Говорите в микрофон
3. Нажмите хоткей снова — появится **"Transcribing…"**
4. Подождите (зависит от длины записи и скорости CPU)
5. Текст напечатается в активное окно и скопируется в буфер обмена

## Возможные проблемы

| Проблема | Решение |
|---|---|
| "No speech detected" | Проверьте микрофон: `parec --list-devices` |
| Очень долгая транскрипция | Используйте q5_0 модель или `small-q5_1` |
| Текст не печатается | Нажмите Ctrl+V — текст в буфере обмена |
| Не запускается запись | Установите `pulseaudio-utils` |
