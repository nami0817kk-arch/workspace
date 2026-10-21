import 'package:flutter/material.dart';

import 'ui/app.dart';
import 'ui/backup_share.dart';
import 'ui/controller.dart';
import 'ui/sound.dart';

void main() => runApp(BaseballManagerApp(
    controller: GameController(
        sound: AudioSound(),
        autoGuide: true,
        sharer: const SharePlusSharer())));
