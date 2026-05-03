import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/aladin_channel_model.dart';

class PlayerPage extends StatefulWidget {
  final ChannelModel channel;
  final List<ChannelModel> playlist; // Tüm kanal listesi
  
  const PlayerPage({
    super.key, 
    required this.channel, 
    required this.playlist,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  static const MethodChannel _exoChannel = MethodChannel('aladin/exoplayer');

  @override
  void initState() {
    super.initState();
    _launchNativePlayer();
  }

  Future<void> _launchNativePlayer() async {
    try {
      final index = widget.playlist.indexOf(widget.channel);
      final urls = widget.playlist.map((e) => e.url).toList();
      final names = widget.playlist.map((e) => e.name).toList();

      await _exoChannel.invokeMethod('playNative', {
        'urls': urls,
        'names': names,
        'index': index >= 0 ? index : 0,
      });
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Native Player Hatası: $e");
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
    );
  }
}
