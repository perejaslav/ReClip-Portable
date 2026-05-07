# ReClip Portable

![Python](https://img.shields.io/badge/Python-3.12-blue)
![Platform](https://img.shields.io/badge/Platform-Windows%2011-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

Портативная сборка ReClip для Windows 11. Автоматическая загрузка и нарезка Reels, Shorts и видео с YouTube через автобраузер.

## Возможности

- 🎬 Скачивание Reels, Shorts и обычных видео с YouTube
- ✂️ Автоматическая нарезка видео по сегментам
- 🌐 Веб-интерфейс через браузер
- 📦 Полностью портативная сборка — не требует установки
- 🔄 Встроенное обновление yt-dlp
- 💾 Все данные хранятся локально

## Быстрый старт

1. Распакуйте архив в папку (желательно без русских символов и пробелов):
   ```
   D:\PortableApps\ReClip-Portable
   ```

2. Запустите `start-reclip-autobrowser.bat`

3. Откройте в браузере:
   ```
   http://127.0.0.1:8899
   ```

## Структура проекта

```
ReClip-Portable/
├── app/                 # Приложение ReClip
├── python/              # Портативный Python 3.12
├── ffmpeg/              # FFmpeg для обработки видео
├── data/downloads/      # Скачанные файлы
├── start-reclip-autobrowser.bat   # Запуск
└── update-ytdlp.bat     # Обновление yt-dlp
```

## Обновление yt-dlp

Если YouTube перестал скачиваться, запустите:
```
update-ytdlp.bat
```

## Системные требования

- Windows 10/11
- Браузер (Chrome, Firefox, Edge)
- Свободное место: ~300 МБ

## Безопасность

- ReClip работает локально (`127.0.0.1`)
- Не отправляет данные на внешние серверы
- Скачивайте только контент, на который у вас есть права

## Лицензия

MIT License

---

**Примечание:** FFmpeg (~193 МБ) включён в сборку. Для экономии места можно скачать его отдельно и заменить файлы в папке `ffmpeg/`.