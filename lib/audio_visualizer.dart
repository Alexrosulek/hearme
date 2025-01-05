import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';

class CircularAudioVisualizer extends StatelessWidget {
  final RecorderController? recorderController;
  final bool isListening;
  final bool isActive;

   const CircularAudioVisualizer({super.key, this.recorderController,
    required this.isListening,
    this.isActive = true});

 

  @override
  Widget build(BuildContext context) {
    final double containerSize = MediaQuery.of(context).size.width * 0.2;
    final double waveformSize = containerSize;

    return Visibility(
      visible: isListening,
      child: SizedBox(
        width: containerSize,
        height: containerSize ,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (recorderController != null)
              Container(
                width: waveformSize,
                height: waveformSize / 2,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AudioWaveforms(
                  recorderController: recorderController!,
                  size: Size(waveformSize, waveformSize / 2),
                  waveStyle: WaveStyle(
                    waveColor: isActive ? Colors.red : Colors.green,
                    waveThickness: 4,
                    spacing: 6,
                    extendWaveform: true,
                    showMiddleLine: false,
                  ),
                ),
              ),
            if (recorderController == null)
              const Text(
                "Listening...",
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }
}
