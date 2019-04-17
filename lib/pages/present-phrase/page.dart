import 'package:flutter/material.dart';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:mlkit/mlkit.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sirene/app.dart';

import 'package:sirene/interfaces.dart';
import 'package:sirene/services/logging.dart';
import 'package:sirene/services/router.dart';

class PresentPhraseOptions {
  final Phrase phrase;
  final bool pauseAfterFinished;

  PresentPhraseOptions({this.phrase, this.pauseAfterFinished});
}

class PresentPhrasePage extends StatefulWidget {
  static setupRoutes(Router r) {
    final h = Router.exactMatchFor(
        route: '/present',
        builder: (_) => PresentPhrasePage(),
        bottomNavCaption: "hello",
        bottomNavIcon: (c) => Icon(
              Icons.settings,
              size: 30,
            ));

    r.routeHandlers.add(h);
    return r;
  }

  @override
  _PresentPhrasePageState createState() => _PresentPhrasePageState();
}

class _PresentPhrasePageState extends State<PresentPhrasePage>
    with LoggerMixin {
  FlutterTts tts;
  PublishSubject<Null> ttsCompletion;
  Map<String, String> languageList;

  bool isCancelled = false;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();

    tts = FlutterTts();
    ttsCompletion = PublishSubject();
    tts.completionHandler = () => ttsCompletion.add(null);
    tts.errorHandler = (e) => ttsCompletion.addError(e);

    Future.delayed(Duration(milliseconds: 10)).then((_) => speakText());
  }

  Future<void> speakText() async {
    PresentPhraseOptions settings = ModalRoute.of(context).settings.arguments;
    final sm = App.locator.get<StorageManager>();

    if (isCancelled) {
      return;
    }

    await tts.setVolume(1.0);

    // TODO: Make this not suck re: locales
    if (languageList == null) {
      List<dynamic> langs = await tts.getLanguages;
      final re = RegExp(r"-.*$");

      languageList = langs.fold(Map(), (acc, x) {
        final langWithLocale = x.toString();
        acc[langWithLocale.replaceAll(re, '')] = langWithLocale;
        return acc;
      });
    }

    if (settings.phrase.detectedLanguage == null) {
      final fli = FirebaseLanguageIdentification.instance;
      settings.phrase.detectedLanguage =
          await fli.identifyLanguage(settings.phrase.text);
    }

    // NB: This code is trickier than it should be, because we can detect
    // a language correctly, but not have a TTS engine for it. Furthermore,
    // a user could use two devices, where one has it and one doesn't, so
    // we don't just want to stomp away the language if we don't have a TTS
    // engine for *this device*.
    var lang = settings.phrase.detectedLanguage;

    // NB: 'und' is what MLKit uses for "undetected"
    if (lang == "und") {
      lang = null;
    }

    if (lang != null && languageList.containsKey(lang)) {
      await tts.setLanguage(languageList[lang]);
    } else {
      lang = await sm.getRecentFallbackLanguage();
      if (lang == null || !languageList.containsKey(lang)) {
        lang = 'en';
      }

      await tts.setLanguage(languageList[lang]);
    }

    if (isCancelled) {
      return;
    }

    isPlaying = true;
    await logAsyncException(() async {
      await tts.speak(settings.phrase.spokenText ?? settings.phrase.text);
      await ttsCompletion.take(1).last;
    }(), rethrowIt: false, message: "Failed to utter text");
    isPlaying = false;

    // NB: This is intentionally not awaited, we don't want to block the user
    // getting back to what they're doing
    logAsyncException(sm.savePresentedPhrase(settings.phrase),
        rethrowIt: false, message: "Failed to update phrase usage info");

    if (isCancelled) {
      return;
    }

    if (!settings.pauseAfterFinished) {
      await Future.delayed(Duration(seconds: 5));

      if (isCancelled) {
        return;
      }

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final turns = isPortrait ? -1 : 0;
    final scrollAxis = isPortrait ? Axis.horizontal : Axis.vertical;

    PresentPhraseOptions settings = ModalRoute.of(context).settings.arguments;

    return Container(
      color: Theme.of(context).primaryColor,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GestureDetector(
          onTap: () async {
            isCancelled = true;
            if (isPlaying) {
              await tts.stop();
            }

            Navigator.of(context).pop();
          },
          child: SingleChildScrollView(
            scrollDirection: scrollAxis,
            child: RotatedBox(
                quarterTurns: turns,
                child: Flex(
                  direction: Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      settings.phrase.text,
                      overflow: TextOverflow.fade,
                      style: Theme.of(context)
                          .primaryTextTheme
                          .headline
                          .merge(TextStyle(fontSize: 96)),
                    )
                  ],
                )),
          ),
        ),
      ),
    );
  }
}
