import 'package:flutter/material.dart';

/// 幅の広い端末(iPad など)か。これを超えると、列を広げて文字を少し大きくする。
const tabletWidth = 700.0;

bool isTablet(BuildContext context) => MediaQuery.sizeOf(context).width >= tabletWidth;

/// 画面の中身の最大幅。スマホは `phone`、iPad は少し広げる(細い帯が中央に残らないように)。
double contentMaxWidth(BuildContext context, {double phone = 560}) =>
    isTablet(context) ? phone + 240 : phone;
