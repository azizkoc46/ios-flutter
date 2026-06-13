import 'dart:io';
import 'package:flutter/cupertino.dart'; // iOS tarzı diyalog ve ikonlar için
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pazarcik_portal/utils/portal_file_upload.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';

class ProfileImagePicker extends StatefulWidget {
  const ProfileImagePicker({
    Key? key,
    required this.selectImage,
    this.isReg = true,
    this.imgUrl = '',
  }) : super(key: key);

  final Function(File) selectImage;
  final bool isReg;
  final String imgUrl;

  @override
  State<ProfileImagePicker> createState() => _ProfileImagePickerState();
}

class _ProfileImagePickerState extends State<ProfileImagePicker> {
  XFile? profileImage;
  final ImagePicker _picker = ImagePicker();

  Future _selectPhoto(ImageSource source) async {
    final XFile? pickedImage = await _picker.pickImage(
      source: source,
      maxWidth: 600,
      maxHeight: 600,
    );

    if (pickedImage == null) return;

    widget.selectImage(File(pickedImage.path));

    setState(() {
      profileImage = pickedImage;
    });
  }

  // iOS Alt Menüsü (Kamera/Galeri Seçimi)
  void _showActionSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Profil Fotoğrafı'),
        message: const Text('Lütfen fotoğraf kaynağını seçin'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: const Text('Kütüphane'),
            onPressed: () {
              _selectPhoto(ImageSource.gallery);
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Kamera'),
            onPressed: () {
              _selectPhoto(ImageSource.camera);
              Navigator.pop(context);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        children: [
          // ANA DAİRE (Görsel Alanı)
          Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7), // iOS Background Gray
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: ClipOval(
              child: profileImage != null
                  ? portalPickedImage(File(profileImage!.path),
                      fit: BoxFit.cover)
                  : (widget.isReg || widget.imgUrl.isEmpty)
                      ? const Icon(
                          CupertinoIcons.person_alt_circle,
                          color: Color(0xFFC7C7CC),
                          size: 90,
                        )
                      : PortalNetworkImage(
                          url: widget.imgUrl,
                          fit: BoxFit.cover,
                          errorWidget: const Icon(
                            CupertinoIcons.person_fill,
                            color: Color(0xFFC7C7CC),
                            size: 60,
                          ),
                        ),
            ),
          ),
          // DÜZENLE BUTONU (Sağ Alt Köşe Aksiyonu)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => _showActionSheet(context),
              child: Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF), // iOS Blue
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.camera_fill,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
