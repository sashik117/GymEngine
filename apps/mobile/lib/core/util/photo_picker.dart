export 'photo_picker_base.dart';
export 'photo_picker_stub.dart'
    if (dart.library.io) 'photo_picker_io.dart'
    if (dart.library.html) 'photo_picker_web.dart'
    show pickPhotoFromDevice;
