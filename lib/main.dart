import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:take_shot_and_save/firebase_options.dart';
import 'package:take_shot_and_save/service/storage_service.dart';

Future<void> main() async {
  // initialize
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // kullanilabilir kameralarin listesi
  final cameras = await availableCameras();

  // spesifik olarak ilk kamera secildi
  final firstCamera = cameras.first;

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      // material icerisinde ilk kamera secilerek fotograf cekildi
      home: TakePictureScreen(
        camera: firstCamera,
      ),
    ),
  );
}

// foto cekmek icin ekran
class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({
    super.key,
    required this.camera,
  });

  final CameraDescription camera;

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  // kamera controller
  late CameraController _controller;
  // initialize edilmesi
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    // camera controller nesnesi uretildi
    _controller = CameraController(
      // secilen ilk kamera tanimlandi
      widget.camera,
      // cozunurluk
      ResolutionPreset.medium,
    );

    // controller initalize edildi ve future dondurdu
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // kamerayla is bitince controllerin dispose edilmesi saglandi
    _controller.dispose();
    super.dispose();
  }

  final Stoarage storage = Stoarage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take a picture')),
      // camera controller initalize edilene kadar bekletildi
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // eger controller ile baglanti saglandiysa fotograf cekme ekranina gidilmesi saglandi
            return CameraPreview(_controller);
          } else {
            // diger durumda indicator donderildi
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      // butona basinca foto cekilmesi saglandi
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // try catch icerisinde foto cekildi
          try {
            await _initializeControllerFuture;

            // Bir resim çekmeyi ve 'görüntü' dosyasını kaydedildiği yere götürüldü
            final XFile image = await _controller.takePicture();
            print('\n***********\n*************\n***************');

            print(image.path);
            print(image.name);
            // await GallerySaver.saveImage(image.path).then((value) => print(value));
            print('\n-------------------------\n-------------------');
            storage.uploadFile(image.path, image.name).onError((error, stackTrace) {
              print(error);
            });
            print('\n-------------------------\n-------------------');

            print('\n***********\n*************\n***************');

            if (!mounted) return;

            // resim cekildiyse yeni ekranda gosterildi
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => DisplayPictureScreen(
                  // Otomatik olarak oluşturulan yol DisplayPictureScreen widgetina iletildi
                  imagePath: image.path,
                  imageName: image.name,
                ),
              ),
            );
          } catch (e) {
            // hata olursa konsolda gosterildi
            print(e);
          }
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}

// Kullanıcı tarafından çekilen resmi görüntüleyen bir widget
class DisplayPictureScreen extends StatefulWidget {
  final String imagePath;
  final String imageName;

  const DisplayPictureScreen({super.key, required this.imagePath, required this.imageName});

  @override
  State<DisplayPictureScreen> createState() => _DisplayPictureScreenState();
}

class _DisplayPictureScreenState extends State<DisplayPictureScreen> {
  final Stoarage stoarage = Stoarage();

  Future<String> verileriAl() async {
    return await stoarage.getFile(widget.imagePath, widget.imageName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Display the Picture')),
      // Görüntü cihazda bir dosya olarak saklanır
      // Görüntüyü görüntülemek için verilen yolla "Image.file" yapıcısı kullanılır
      body: Column(
        children: [
          Image.file(File(widget.imagePath)),
          const SizedBox(height: 20),
          FutureBuilder(
            // future: stoarage.getFile(widget.imagePath, widget.imageName),
            future: verileriAl(),
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              switch (snapshot.connectionState) {
                case ConnectionState.none:
                  return const Text('bir sorun olustu');

                case ConnectionState.waiting:
                  return const Center(child: CircularProgressIndicator());
                case ConnectionState.active:
                  return const Center(child: CircularProgressIndicator());

                case ConnectionState.done:
                  print('bu kisma giriyor');
                  if (snapshot.hasData) {
                    print(snapshot.data);
                    return ListTile(
                      leading: const Text('okul no\n190290050'),
                      title: Image.network(snapshot.data),
                      subtitle: Text(snapshot.data),
                      trailing: const Icon(Icons.school),
                    );
                  } else {
                    return SizedBox(
                      height: 50,
                      width: 200,
                      child: ElevatedButton(
                          onPressed: () {
                            setState(() {});
                          },
                          child: const Text('Url al')),
                    );
                  }
              }
            },
          ),
        ],
      ),
    );
  }
}
