import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

import '../application/aiko_rive_runtime.dart';
import 'aiko_art_fallback.dart';

enum AikoMood { neutral, thinking, happy, worried, celebrating }

extension AikoMoodContract on AikoMood {
  double get riveValue => switch (this) {
    AikoMood.neutral => 0.0,
    AikoMood.thinking => 1.0,
    AikoMood.happy => 2.0,
    AikoMood.worried => 3.0,
    AikoMood.celebrating => 4.0,
  };

  String get fallbackAsset => switch (this) {
    AikoMood.neutral => 'assets/images/aiko/aiko_welcome.png',
    AikoMood.thinking => 'assets/images/aiko/aiko_thinking.png',
    AikoMood.happy => 'assets/images/aiko/aiko_happy.png',
    AikoMood.worried => 'assets/images/aiko/aiko_warning.png',
    AikoMood.celebrating => 'assets/images/aiko/aiko_celebrating.png',
  };
}

class AikoCharacter extends StatefulWidget {
  const AikoCharacter({
    required this.mood,
    required this.semanticLabel,
    this.active = true,
    this.size = 220,
    super.key,
  });

  final AikoMood mood;
  final String semanticLabel;
  final bool active;
  final double size;

  @override
  State<AikoCharacter> createState() => _AikoCharacterState();
}

class _AikoCharacterState extends State<AikoCharacter> {
  rive.FileLoader? _fileLoader;
  Future<rive.File>? _fileLoad;
  rive.ViewModelInstance? _viewModelInstance;
  bool _hasValidViewModel = false;
  bool _motionEnabled = true;

  @override
  void initState() {
    super.initState();
    _createLoaderIfReady();
    AikoRiveRuntime.ready.addListener(_onRuntimeReady);
  }

  void _onRuntimeReady() => setState(_createLoaderIfReady);

  /// The animation loads only once the Rive runtime is ready; until then (or
  /// if it never is) the PNG fallback shows.
  void _createLoaderIfReady() {
    if (!AikoRiveRuntime.ready.value || _fileLoader != null) return;
    final loader = rive.FileLoader.fromAsset(
      AikoRiveRuntime.asset,
      riveFactory: rive.Factory.rive,
    );
    _fileLoader = loader;
    // RiveWidgetBuilder observes the shared load and renders any failure.
    _fileLoad = loader.file()..ignore();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionEnabled = !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    _syncViewModel();
  }

  @override
  void didUpdateWidget(covariant AikoCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncViewModel();
  }

  void _handleLoaded(rive.RiveLoaded state) {
    final viewModelInstance = state.viewModelInstance;
    _hasValidViewModel =
        viewModelInstance != null &&
        viewModelInstance.number('mood') != null &&
        viewModelInstance.boolean('active') != null &&
        viewModelInstance.boolean('motionEnabled') != null;
    _viewModelInstance = _hasValidViewModel ? viewModelInstance : null;
    _syncViewModel();
  }

  void _syncViewModel() {
    final viewModelInstance = _viewModelInstance;
    if (viewModelInstance == null) {
      return;
    }

    viewModelInstance.number('mood')?.value = widget.mood.riveValue;
    viewModelInstance.boolean('active')?.value = widget.active;
    viewModelInstance.boolean('motionEnabled')?.value = _motionEnabled;
  }

  @override
  void dispose() {
    AikoRiveRuntime.ready.removeListener(_onRuntimeReady);
    final loader = _fileLoader;
    if (loader != null) _fileLoad!.whenComplete(loader.dispose).ignore();
    super.dispose();
  }

  /// The still PNG for the current mood, shown until (or instead of) the
  /// animation; a stand-in when even that can't load.
  Widget _stillArt() => Image.asset(
    widget.mood.fallbackAsset,
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) => const AikoArtFallback(),
  );

  @override
  Widget build(BuildContext context) {
    final fileLoader = _fileLoader;
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: widget.size,
          child: fileLoader == null
              ? _stillArt()
              : rive.RiveWidgetBuilder(
                  fileLoader: fileLoader,
                  artboardSelector: rive.ArtboardSelector.byName('Aiko'),
                  stateMachineSelector: rive.StateMachineSelector.byName(
                    'AikoState',
                  ),
                  dataBind: rive.DataBind.auto(),
                  onLoaded: _handleLoaded,
                  builder: (context, state) => switch (state) {
                    rive.RiveLoaded() when !_hasValidViewModel => _stillArt(),
                    rive.RiveLoaded(:final controller) => rive.RiveWidget(
                      controller: controller,
                      fit: rive.Fit.contain,
                    ),
                    rive.RiveLoading() || rive.RiveFailed() => _stillArt(),
                  },
                ),
        ),
      ),
    );
  }
}
