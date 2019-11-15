# MarkovChainPascal

## ArchLinux
```bash
sudo pacman -S lazarus lib32-openssl
sudo rm /usr/lib/libssl.so
sudo ln -s /usr/lib/libssl.so.1.0.0 /usr/lib/libssl.so
lazbuild kbot.lpi
```

## Ubuntu
Install lazarus, fpc-laz and fpc-src from 
https://sourceforge.net/projects/lazarus/files/Lazarus%20Linux%20amd64%20DEB/Lazarus%202.0.6/
```bash
lazbuild kbot.lpi
```

Создай файл "bot.cfg" с содержимым

```json
{"token":"токен","group_id":ид_группы}
```
Версия LongPoll API: 5.101
