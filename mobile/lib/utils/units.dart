import 'dart:ui';

enum DistanceUnit { km, mi }

const _mileCountries = {'US', 'GB', 'LR', 'MM'};

DistanceUnit defaultUnitFor(Locale locale) =>
    _mileCountries.contains(locale.countryCode) ? DistanceUnit.mi : DistanceUnit.km;
