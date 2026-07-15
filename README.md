# Голосовая диктовка в текст (Voice-to-Text Dictation)

Real-time голосовая диктовка через [whisper.cpp](https://github.com/ggml-org/whisper.cpp) на Wayland (GNOME).

## Как работает

- **Хоткей** → `whisper-stream` транскрибирует микрофон в реальном времени
- Пока говорите — **текст сам печатается** в активное окно и обновляется в **буфере обмена**
- **Хоткей снова** → завершение, финальный текст в буфере
- Можно переключать окна — текст идёт туда, где фокус

## Требования

```bash
sudo pacman -S wtype wl-clipboard libnotify pulseaudio-utils
```

- **whisper.cpp** — собранный с `WHISPER_SDL2=ON`
- **wtype** — эмуляция клавиатуры Wayland
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

Для быстрой диктовки (рекомендуется):

```bash
bash models/download-ggml-model.sh small-q5_1
```

Для лучшего качества (медленнее):

```bash
bash models/download-ggml-model.sh large-v3-turbo-q5_0
```

### 3. Скопировать скрипт

```bash
cp whisper-dictation.sh ~/whisper.cpp/
chmod +x ~/whisper.cpp/whisper-dictation.sh
```

### 4. Настроить скрипт

В начале `whisper-dictation.sh`:

| Переменная | По умолчанию | Описание |
|---|---|---|
| `MODEL` | `small-q5_1.bin` | Путь к модели |
| `LANGUAGE` | `ru` | Язык распознавания |
| `THREADS` | `8` | Число потоков CPU |

### 5. Настроить хоткей

**GUI:** Настройки → Клавиатура → Сочетания клавиш → Пользовательские сочетания → Добавить

- Имя: `Dictation`
- Команда: полный путь, напр. `/home/user/whisper.cpp/whisper-dictation.sh`
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
3. Через 5-7 секунд (первый инференс) текст появляется в активном окне
4. Каждые 3-5 секунд допечатываются новые слова, буфер обмена обновляется
5. **Хоткей снова** → завершение (ждёт окончания текущего инференса)
6. Если текст не напечатался — `Ctrl+V` в любом месте

## Почему small-q5_1, а не large?

| Модель | Размер | Инференс (на CPU 8 ядер) |
|---|---|---|
| `small-q5_1` | 182 MB | **3-5 сек** на 3-сек аудио |
| `large-v3-turbo-q5_0` | 548 MB | 10-12 сек на 3-сек аудио |

Для real-time диктовки small-q5_1 даёт приемлемое качество и незаметную задержку.

## Как это устроено

1. `whisper-stream` транскрибирует аудио скользящим окном (10 сек, шаг 3 сек)
2. `tail -f --pid` читает новые строки по мере появления
3. Для каждой строки вычисляется **дельта** (слова, не перекрывающиеся с предыдущей)
4. `wtype` печатает дельту, `wl-copy` копирует полный текст
5. При остановке скрипт ждёт завершения текущего инференса, затем убивает процесс

## Возможные проблемы

| Проблема | Решение |
|---|---|
| "Речь не распознана" | Говорите громче, ждите 7-10 сек до первого инференса |
| Текст не печатается | `Ctrl+V` — текст в буфере |
| Очень долго | Переключитесь на `small-q5_1` |
| Не запускается | `cat /tmp/whisper-dictation.log` — что в логе? |
