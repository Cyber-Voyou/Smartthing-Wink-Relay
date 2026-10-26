# Installer et configurer Wink Relay Manager

Le logiciel Wink appartient au projet tiers [jimpastos/wink-relay-manager](https://github.com/jimpastos/wink-relay-manager). Lisez sa licence et ses instructions originales avant toute modification. Le Wink Relay doit être rooté et accessible par ADB. Les opérations sur `/system`, la désactivation du logiciel Wink d'origine et le redémarrage peuvent rendre l'appareil inutilisable : sauvegardez-le et procédez à vos risques.

## Préparation

1. Compiler `wink_manager` avec l'ancien Android NDK indiqué par le projet amont, ou utiliser un binaire obtenu d'une source de confiance et en vérifier le hash.
2. Copier `examples/wink-manager/wink_manager.ini.example` hors du dépôt et remplacer l'adresse, le préfixe, l'identifiant et le mot de passe.
3. Utiliser un `mqtt_clientid` et un `mqtt_topic_prefix` uniques pour chaque Wink.

## Installation ADB

Les commandes suivantes résument la procédure amont; vérifiez toujours le nom de l'appareil avec `adb devices` :

```sh
adb push wink_manager /sdcard/wink_manager
adb push wink_manager.ini /sdcard/wink_manager.ini
adb shell
su
pm disable com.quirky.android.wink.projectone
mount -o rw,remount /system
cp /sdcard/wink_manager /system/bin/edisonwink
chmod 755 /system/bin/edisonwink
reboot
```

Ne placez jamais le mot de passe dans ce dépôt, une capture d'écran, un rapport ou une commande publiée.

## Modes des boutons

Les drapeaux sont additionnés bit à bit : `1` bascule le relais, `2` publie le clic, `4` publie l'appui long, `8` publie le relâchement, `16` gère le blocage tactile, `32` bascule le relais opposé.

- Deux lumières indépendantes : `relay_upper_flags=3`, `relay_lower_flags=3`.
- Une lumière commandée par les deux boutons : `relay_upper_flags=3`, `relay_lower_flags=35`; sélectionner ensuite « One light » dans SmartThings.

N'ajoutez pas d'état initial sauf si vous acceptez qu'un redémarrage puisse commuter une charge.
