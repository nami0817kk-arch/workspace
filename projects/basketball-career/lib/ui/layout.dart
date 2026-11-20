import 'package:flutter/material.dart';

/// 幅の広い端末(iPad など)か。横画面専用なので、スマホの横(〜932)より広いところを iPad とする。
/// これを超えると、画面全体を拡大して、列を広げる。
const tabletWidth = 1000.0;

bool isTablet(BuildContext context) => MediaQuery.sizeOf(context).width >= tabletWidth;

/// 画面の中身の最大幅。スマホは `phone`、iPad は少し広げる(細い帯が中央に残らないように)。
double contentMaxWidth(BuildContext context, {double phone = 560}) =>
    isTablet(context) ? phone + 240 : phone;
