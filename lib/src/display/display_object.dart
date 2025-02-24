import 'dart:ui' as ui;

import 'package:flutter/painting.dart' as painting;

import '../../graphx.dart';

abstract class GDisplayObject
    with
        DisplayListSignalsMixin,
        RenderSignalMixin,
        MouseSignalsMixin,
        DisplayMasking {
  GDisplayObjectContainer? $parent;
  static GDisplayObject? $currentDrag;
  static GRect? $currentDragBounds;
  late GPoint _dragCenterOffset;

  /// Lets the user drag the specified sprite.
  /// The sprite remains draggable until explicitly stopped through a call to
  /// the Sprite.stopDrag() method, or until another sprite is made draggable.
  /// Only one sprite is draggable at a time.
  /// [lockCenter] (false) Specifies whether the draggable sprite is locked to
  /// the center of the pointer position (true), or locked to the point where
  /// the user first clicked the sprite (false).
  /// [bounds] Value relative to the coordinates of the Sprite's parent that
  /// specify a constraint rectangle for the Sprite.
  void startDrag([bool lockCenter = false, GRect? bounds]) {
    if (!inStage || !$hasTouchableArea) {
      throw 'to drag an object, it has to be visible and enabled in the stage.';
    }

    $currentDrag?.stopDrag();
    $currentDrag = this;
    $currentDragBounds = bounds;
    _dragCenterOffset = GPoint();
    if (lockCenter) {
      _dragCenterOffset.setTo(x - parent!.mouseX, y - parent!.mouseY);
    }
    stage!.onMouseMove.add(_handleDrag);
  }

// DisplayObject get dropTarget {
//   if ($parent == null || !$hasVisibleArea || !inStage) return null;
//   if ($parent.children.length > 1) {
//     GxRect rect;
//     $parent.children.forEach((child) {
//       child.getBounds($parent, rect);
//     });
//   }
// }

  void _handleDrag(MouseInputData input) {
    if (this != $currentDrag) {
      stage?.onMouseMove.remove(_handleDrag);
    }
    if ($currentDrag == null) {
      $currentDragBounds = null;
      return;
    }
    var tx = $currentDrag!.parent!.mouseX + _dragCenterOffset.x;
    var ty = $currentDrag!.parent!.mouseY + _dragCenterOffset.y;
    final rect = $currentDragBounds;
    if (rect != null) {
      tx = tx.clamp(rect.left, rect.right);
      ty = ty.clamp(rect.top, rect.bottom);
    }
    setPosition(tx, ty);
  }

  void stopDrag() {
    if (this == $currentDrag) {
      stage!.onMouseMove.remove(_handleDrag);
      $currentDrag = null;
    }
  }

  bool $debugBounds = false;
  bool mouseUseShape = false;

  List<GBaseFilter>? $filters;

  List<GBaseFilter>? get filters => $filters;

  set filters(List<GBaseFilter>? value) => $filters = value;

  GDisplayObject? $mouseDownObj;
  GDisplayObject? $mouseOverObj;

  double $lastClickTime = -1;

  bool useCursor = false;

  ui.Color? $colorize = kColorTransparent;

  bool get $hasColorize => $colorize != null && $colorize!.alpha > 0;

  ui.Color? get colorize => $colorize;

  set colorize(ui.Color? value) {
    if ($colorize == value) return;
    $colorize = value;
    requiresRedraw();
  }

  /// capture context mouse inputs.
  void captureMouseInput(MouseInputData input) {
    if (!$hasTouchableArea) return;
    if (mouseEnabled) {
      if (input.captured && input.type == MouseInputType.up) {
        $mouseDownObj = null;
      }
      var prevCaptured = input.captured;
      globalToLocal(input.stagePosition, input.localPosition);
      input.captured = input.captured ||
          hitTouch(
            input.localPosition,
            mouseUseShape,
          );
      if (!prevCaptured && input.captured) {
        $dispatchMouseCallback(input.type, this, input);
        if ($mouseOverObj != this) {
          $dispatchMouseCallback(MouseInputType.over, this, input);
        }
      } else if ($mouseOverObj == this) {
        $dispatchMouseCallback(MouseInputType.out, this, input);
      }
    }
  }

  void $dispatchMouseCallback(
    MouseInputType type,
    GDisplayObject object,
    MouseInputData input,
  ) {
    if (mouseEnabled) {
      var mouseInput = input.clone(this, object, type);
      switch (type) {
        case MouseInputType.zoomPan:
          $onZoomPan?.dispatch(mouseInput);
          break;
        case MouseInputType.wheel:
          $onMouseWheel?.dispatch(mouseInput);
          break;
        case MouseInputType.down:
          $mouseDownObj = object;
          $onMouseDown?.dispatch(mouseInput);
          break;
//        case MouseInputType.rightDown:
//          $rightMouseDownObj = object;
//          $onRightMouseDown?.dispatch(mouseInput);
//          break;
        case MouseInputType.move:
          $onMouseMove?.dispatch(mouseInput);
          break;
        case MouseInputType.up:
          if ($mouseDownObj == object &&
              ($onMouseClick != null || $onMouseDoubleClick != null)) {
            var mouseClickInput = input.clone(this, object, MouseInputType.up);
            $onMouseClick?.dispatch(mouseClickInput);

            if ($lastClickTime > 0 &&
                input.time - $lastClickTime < MouseInputData.doubleClickTime) {
              $onMouseDoubleClick?.dispatch(mouseClickInput);
              $lastClickTime = -1;
            } else {
              $lastClickTime = input.time;
            }
          }
          $mouseDownObj = null;
          $onMouseUp?.dispatch(mouseInput);
          break;
        case MouseInputType.over:
          $mouseOverObj = object;
          if (useCursor && GMouse.isShowing()) {
            GMouse.setClickCursor();
          }
          $onMouseOver?.dispatch(mouseInput);
          break;
        case MouseInputType.out:
          $mouseOverObj = null;

          /// TODO: check if other object on top receives the event
          /// todo. before this one, and Cursor loses the stage.
          if (useCursor && GMouse.isShowing()) {
            GMouse.basic();
          }
          $onMouseOut?.dispatch(mouseInput);
          break;
        default:
          break;
      }
    }
    $parent?.$dispatchMouseCallback(type, object, input);
  }

  /// todo: add caching to local bounds (Rect).
//  Rect _nativeBounds;
//  GxRect _cachedBounds;

  @override
  String toString() {
    final msg = name != null ? ' {name: $name}' : '';
    return '$runtimeType (DisplayObject)$msg';
  }

  double get mouseX {
    if (inStage) {
      return globalToLocal(
        _sHelperPoint.setTo(
          stage!.pointer!.mouseX,
          stage!.pointer!.mouseY,
        ),
        _sHelperPoint,
      ).x;
    } else {
      throw 'To get mouseX object needs to be a descendant of Stage.';
    }
  }

  double get mouseY {
    if (inStage) {
      return globalToLocal(
        _sHelperPoint.setTo(
          stage!.pointer!.mouseX,
          stage!.pointer!.mouseY,
        ),
        _sHelperPoint,
      ).y;
    } else {
      throw 'To get mouseY object needs to be a descendant of Stage.';
    }
  }

  GPoint get mousePosition {
    if (!inStage) {
      throw 'To get mousePosition, the object needs to be in the Stage.';
    }
    return globalToLocal(_sHelperPoint.setTo(
      stage!.pointer!.mouseX,
      stage!.pointer!.mouseY,
    ));
  }

  /// You can store any user defined data in this property for easy access.
  Object? userData;
  String? name;

  double _x = 0, _y = 0, _scaleX = 1, _scaleY = 1, _rotation = 0;
  double _pivotX = 0, _pivotY = 0;
  double _skewX = 0, _skewY = 0;
  double _z = 0, _rotationX = 0, _rotationY = 0;

  double get rotationX => _rotationX;

  double get rotationY => _rotationY;

  double get z => _z;

  double get x => _x;

  double get y => _y;

  double get scaleX => _scaleX;

  double get scaleY => _scaleY;

  double get pivotX => _pivotX;

  double get pivotY => _pivotY;

  double get skewX => _skewX;

  double get skewY => _skewY;

  double get rotation => _rotation;

  /// Indicates the width of the display object, in dp.
  /// The `width` is calculated based on the bounds of the content of the
  /// display object.
  /// When you set the `width` property, the `scaleX` property is adjusted
  /// accordingly, as shown in the following code:
  /// ```dart
  ///   var rect:Shape = new Shape();
  ///   rect.graphics.beginFill(0xFF0000);
  ///   rect.graphics.drawRect(0, 0, 100, 100);
  ///   trace(rect.scaleX) // 1;
  ///   rect.width = 200;
  ///   trace(rect.scaleX) // 2;
  /// ```
  /// A display object with no content (such as an empty sprite) has a width
  /// of 0, even if you try to set width to a different value.
  double get width => getBounds($parent, _sHelperRect)!.width;

  /// Indicates the height of the display object, in dp.
  /// The `height` is calculated based on the bounds of the content of the
  /// display object.
  /// When you set the `height` property, the `scaleX` property is adjusted
  /// accordingly, as shown in the following code:
  /// ```dart
  ///   var rect:Shape = new Shape();
  ///   rect.graphics.beginFill(0xFF0000);
  ///   rect.graphics.drawRect(0, 0, 100, 100);
  ///   trace(rect.scaleY) // 1;
  ///   rect.height = 200;
  ///   trace(rect.scaleY) // 2;
  /// ```
  /// A display object with no content (such as an empty sprite) has a height
  /// of 0, even if you try to set height to a different value.
  double get height => getBounds($parent, _sHelperRect)!.height;

  set width(double? value) {
    if (value?.isNaN ?? true) throw '[$this.width] can not be NaN nor null';
    double? actualW;
    var zeroScale = _scaleX < 1e-8 && _scaleX > -1e-8;
    if (zeroScale) {
      scaleX = 1.0;
      actualW = width;
    } else {
      actualW = (width / _scaleX).abs();
    }
    scaleX = value! / actualW;
  }

  set height(double? value) {
    if (value?.isNaN ?? true) throw '[$this.height] can not be NaN nor null';
    double? actualH;
    var zeroScale = _scaleY < 1e-8 && _scaleY > -1e-8;
    if (zeroScale) {
      scaleY = 1.0;
      actualH = height;
    } else {
      actualH = (height / _scaleY).abs();
    }
    scaleY = value! / actualH;
  }

  set x(double? value) {
    if (value?.isNaN ?? true) throw '[$this.x] can not be NaN nor null';
    if (_x == value) return;
    _x = value!;
    $setTransformationChanged();
  }

  set y(double? value) {
    if (value?.isNaN ?? true) throw '[$this.y] can not be NaN nor null';
    if (_y == value) return;
    _y = value!;
    $setTransformationChanged();
  }

  set scaleX(double? value) {
    if (value?.isNaN ?? true) throw '[$this.scaleX] can not be NaN nor null';
    if (_scaleX == value) return;
    _scaleX = value!;
    $setTransformationChanged();
  }

  set scaleY(double? value) {
    if (value?.isNaN ?? true) throw '[$this.scaleY] can not be NaN nor null';
    if (_scaleY == value) return;
    _scaleY = value!;
    $setTransformationChanged();
  }

  set pivotX(double value) {
    if (value.isNaN) throw '[$this.pivotX] can not be NaN nor null';
    if (_pivotX == value) return;
    _pivotX = value;
    $setTransformationChanged();
  }

  set pivotY(double value) {
    if (value.isNaN) throw '[$this.pivotY] can not be NaN nor null';
    if (_pivotY == value) return;
    _pivotY = value;
    $setTransformationChanged();
  }

  set skewX(double value) {
    if (value.isNaN) throw '[$this.skewX] can not be NaN nor null';
    if (_skewX == value) return;
    _skewX = value;
    $setTransformationChanged();
  }

  set skewY(double value) {
    if (value.isNaN) throw '[$this.skewY] can not be NaN';
    if (_skewY == value) return;
    _skewY = value;
    $setTransformationChanged();
  }

  set rotation(double? value) {
    if (value?.isNaN ?? true) throw '[$this.rotation] can not be NaN nor null';
    if (_rotation == value) return;
    _rotation = value!;
    $setTransformationChanged();
  }

  set rotationX(double value) {
    if (value.isNaN) throw '[$this.rotationX] can not be NaN';
    if (_rotationX == value) return;
    _rotationX = value;
    if (!_isWarned3d) _warn3d();
    $setTransformationChanged();
  }

  set rotationY(double value) {
    if (value.isNaN) throw '[$this.rotationY] can not be NaN';
    if (_rotationY == value) return;
    _rotationY = value;
    if (!_isWarned3d) _warn3d();
    $setTransformationChanged();
  }

  set z(double value) {
    if (value.isNaN) throw '[$this.z] can not be NaN';
    if (_z == value) return;
    _z = value;
    if (!_isWarned3d) _warn3d();
    $setTransformationChanged();
  }

  static bool _isWarned3d = false;

  void _warn3d() {
    if (kDebugMode) {
      print('Warning: 3d transformations still not properly supported');
    }
    _isWarned3d = true;
  }

  double $alpha = 1;

  double get alpha => $alpha;

  set alpha(double value) {
    if ($alpha != value) {
      // value ??= 1;
      $alpha = value.clamp(0.0, 1.0);
      requiresRedraw();
    }
  }

  bool get isRotated => _rotation != 0 || _skewX != 0 || _skewY != 0;

  bool $matrixDirty = true;
  bool mouseEnabled = true;

  GDisplayObject? $maskee;
  GShape? $mask;

  /// optimization.
  bool $hasTouchableArea = true;
  bool $hasVisibleArea = true;

  bool get isMask => $maskee != null;

  GShape? get mask => $mask;

  /// can be set on the Shape mask, or the maskee DisplayObject.
  bool maskInverted = false;

  set mask(GShape? value) {
    if ($mask != value) {
      if ($mask != null) $mask!.$maskee = null;
      value?.$maskee = this;
      value?.$hasVisibleArea = false;
      $mask = value;
      requiresRedraw();
    }
  }

  /// to detect matrix change.
  bool _transformationChanged = false;
  bool _is3D = false;

  void $setTransformationChanged() {
    _transformationChanged = true;
    _is3D = _rotationX != 0 || _rotationY != 0 || _z != 0;
    requiresRedraw();
  }

  /// common parent.
  static final List<GDisplayObject> _sAncestors = [];
  static final GPoint _sHelperPoint = GPoint();
  static final GRect _sHelperRect = GRect();
  static final GMatrix _sHelperMatrix = GMatrix();
  static final GMatrix _sHelperMatrixAlt = GMatrix();

  double get worldAlpha => alpha * ($parent?.worldAlpha ?? 1);

  double get worldScaleX => scaleX * ($parent?.worldScaleX ?? 1);

  double get worldScaleY => scaleX * ($parent?.worldScaleY ?? 1);

  double get worldX => x - pivotX * scaleX + ($parent?.worldX ?? 0);

  double get worldY => y - pivotY * scaleY + ($parent?.worldY ?? 0);

  /// Toggles the visibility state of the object.
  /// Whether or not the display object is visible.
  /// Display objects that are not visible are disabled.
  /// For example, if visible=false it cannot be clicked and it will not be
  /// rendered.
  bool _visible = true;

  bool get visible => _visible;

  set visible(bool flag) {
    if (_visible != flag) {
      _visible = flag;
      requiresRedraw();
    }
  }

  GDisplayObject() {
    _x = _y = 0.0;
    _rotation = 0.0;
    alpha = 1.0;
    _pivotX = _pivotY = 0.0;
    _scaleX = _scaleY = 1.0;
    _skewX = _skewY = 0.0;
    _rotationX = _rotationY = 0.0;
    mouseEnabled = true;
  }

  void alignPivot([painting.Alignment alignment = painting.Alignment.center]) {
    var bounds = getBounds(this, _sHelperRect)!;

    if (bounds.isEmpty) return;
    var ax = 0.5 + alignment.x / 2;
    var ay = 0.5 + alignment.y / 2;

    pivotX = bounds.x + bounds.width * ax;
    pivotY = bounds.y + bounds.height * ay;
  }

  /// local bounds
  /// todo: should be cached.
  GRect? get bounds => getBounds(this);

  GRect? getBounds(GDisplayObject? targetSpace, [GRect? out]) {
    throw 'getBounds() is abstract in DisplayObject';
  }

  GPoint globalToLocal(GPoint globalPoint, [GPoint? out]) {
    getTransformationMatrix(base, _sHelperMatrixAlt);
    _sHelperMatrixAlt.invert();
    return _sHelperMatrixAlt.transformPoint(globalPoint, out);
  }

  GPoint localToGlobal(GPoint localPoint, [GPoint? out]) {
    getTransformationMatrix(base, _sHelperMatrixAlt);
    return _sHelperMatrixAlt.transformPoint(localPoint, out);
  }

  GMatrix? _transformationMatrix;

  GMatrix get transformationMatrix {
    if (_transformationChanged || _transformationMatrix == null) {
      _transformationChanged = false;
      _transformationMatrix ??= GMatrix();
//      _transformationMatrix.setTransform(
//        x,
//        y,
//        pivotX,
//        pivotY,
//        scaleX,
//        scaleY,
//        skewX,
//        skewY,
//        rotation,
//      );
      $updateTransformationMatrices(
        x,
        y,
        pivotX,
        pivotY,
        scaleX,
        scaleY,
        skewX,
        skewY,
        rotation,
        _transformationMatrix!,
      );
    }
    return _transformationMatrix!;
  }

  set transformationMatrix(GMatrix matrix) {
    const piQuarter = Math.PI / 4.0;
    requiresRedraw();
    _transformationChanged = false;
    _transformationMatrix ??= GMatrix();
    _transformationMatrix!.copyFrom(matrix);
    _pivotX = _pivotY = 0;
    _x = matrix.tx;
    _y = matrix.ty;
    _skewX = Math.atan(-matrix.c / matrix.d);
    _skewY = Math.atan(matrix.b / matrix.a);
    _scaleY = (_skewX > -piQuarter && _skewX < piQuarter)
        ? matrix.d / Math.cos(_skewX)
        : -matrix.c / Math.sin(_skewX);
    _scaleX = (_skewY > -piQuarter && _skewY < piQuarter)
        ? matrix.a / Math.cos(_skewY)
        : -matrix.b / Math.sin(_skewY);
    if (MathUtils.isEquivalent(_skewX, _skewY)) {
      _rotation = _skewX;
      _skewX = _skewY = 0;
    } else {
      _rotation = 0;
    }
  }

  void $updateTransformationMatrices(
    double? x,
    double? y,
    double pivotX,
    double pivotY,
    double scaleX,
    double scaleY,
    double skewX,
    double skewY,
    double rotation,
    GMatrix out,
  ) {
    out.identity();
    if (skewX == 0 && skewY == 0) {
      /// optimization, no skewing.
      if (rotation == 0) {
        out.setTo(
          scaleX,
          0,
          0,
          scaleY,
          x! - pivotX * scaleX,
          y! - pivotY * scaleY,
        );
      } else {
        final cos = Math.cos(rotation);
        final sin = Math.sin(rotation);
        final a = scaleX * cos;
        final b = scaleX * sin;
        final c = scaleY * -sin;
        final d = scaleY * cos;
        final tx = x! - pivotX * a - pivotY * c;
        final ty = y! - pivotX * b - pivotY * d;
        out.setTo(a, b, c, d, tx, ty);
      }
    } else {
      out.identity();
      out.scale(scaleX, scaleY);
      out.skew(skewX, skewY); // MatrixUtils.skew(out, skewX, skewY);
      out.rotate(rotation);
      out.translate(x!, y!);
      if (pivotX != 0 || pivotY != 0) {
        out.tx = x - out.a * pivotX - out.c * pivotY;
        out.ty = y - out.b * pivotX - out.d * pivotY;
      }
    }
  }

  GMatrix getTransformationMatrix(GDisplayObject? targetSpace, [GMatrix? out]) {
    GDisplayObject? commonParent, currentObj;
    out?.identity();
    out ??= GMatrix();
    if (targetSpace == this) {
      return out;
    }
    if (targetSpace == $parent || (targetSpace == null && $parent == null)) {
      out.copyFrom(transformationMatrix);
      return out;
    }
    if (targetSpace == null || targetSpace == base) {
      currentObj = this;
      while (currentObj != targetSpace) {
        out.concat(currentObj!.transformationMatrix);
        currentObj = currentObj.$parent;
      }
      return out;
    }
    if (targetSpace.$parent == this) {
      // optimization.
      targetSpace.getTransformationMatrix(this, out);
      out.invert();
      return out;
    }

    /// 1 - find a common parent between this and targetSpace.
    commonParent = GDisplayObject._findCommonParent(this, targetSpace);

    /// 2 - move up from this to common parent.````
    currentObj = this;
    while (currentObj != commonParent) {
      out.concat(currentObj!.transformationMatrix);
      currentObj = currentObj.$parent;
    }

    if (commonParent == targetSpace) return out;

    /// 3. move up from target until we reach common parent.
    _sHelperMatrix.identity();
    currentObj = targetSpace;
    while (currentObj != commonParent) {
      _sHelperMatrix.concat(currentObj!.transformationMatrix);
      currentObj = currentObj.$parent;
    }

    /// 4. combine the matrices.
    _sHelperMatrix.invert();
    out.concat(_sHelperMatrix);
    return out;
  }

  static GDisplayObject _findCommonParent(
      GDisplayObject obj1, GDisplayObject obj2) {
    GDisplayObject? current = obj1;

    /// TODO: use faster Hash access.
    while (current != null) {
      _sAncestors.add(current);
      current = current.$parent;
    }
    current = obj2;
    while (current != null && !_sAncestors.contains(current)) {
      current = current.$parent;
    }
    _sAncestors.length = 0;
    if (current != null) return current;
    throw 'Object not connected to target';
  }

  bool hitTestMask(GPoint localPoint) {
    if ($mask == null && maskRect == null) {
      return true;
    }
    if (maskRect != null) {
      final isHit = maskRect!.containsPoint(localPoint);
      return maskRectInverted ? !isHit : isHit;
    }
    if ($mask!.inStage) {
      getTransformationMatrix($mask, _sHelperMatrixAlt);
    } else {
      _sHelperMatrixAlt.copyFrom($mask!.transformationMatrix);
      _sHelperMatrixAlt.invert();
    }

    var helperPoint = localPoint == _sHelperPoint ? GPoint() : _sHelperPoint;
    _sHelperMatrixAlt.transformPoint(localPoint, helperPoint);

    final isHit = mask!.hitTest(helperPoint) != null;
//    return maskInverted ? !isHit : isHit;
    return maskInverted ? !isHit : isHit;
  }

  bool hitTouch(GPoint localPoint, [bool useShape = false]) {
    return hitTest(localPoint, useShape) != null;
  }

  /// `useShape` is meant to be used by `Shape.graphics`.
  GDisplayObject? hitTest(GPoint localPoint, [bool useShape = false]) {
    if (!$hasTouchableArea || !mouseEnabled) {
      return null;
    }
    if (($mask != null || maskRect != null) && !hitTestMask(localPoint)) {
      return null;
    }
    if (getBounds(this, _sHelperRect)!.containsPoint(localPoint)) {
      return this;
    }
    return null;
  }

  GDisplayObjectContainer? get parent => $parent;

  GDisplayObject get base {
    var current = this;
    while (current.$parent != null) {
      current = current.$parent!;
    }
    return current;
  }

  bool get inStage => base is Stage;

  Stage? get stage => base is Stage ? base as Stage? : null;

  GDisplayObject? get root {
    var current = this;
    while (current.$parent != null) {
      if (current.$parent is Stage) return current;
      current = current.$parent!;
    }
    return null;
  }

  /// rendering.
  void requiresRedraw() {
    /// TODO: notify parent the current state of this DisplayObject.
    $hasTouchableArea =
        visible && $maskee == null && _scaleX != 0 && _scaleY != 0;

    $hasVisibleArea = $alpha != 0 &&
        visible &&
        $maskee == null &&
        _scaleX != 0 &&
        _scaleY != 0;
  }

  void removedFromStage() {}

  void addedToStage() {}

  @mustCallSuper
  void update(double delta) {}

  bool get hasFilters => filters?.isNotEmpty ?? false;
  GRect? $debugLastLayerBounds;

  /// quick and dirty way to toggle saveLayer() feature for common
  /// display objects as well.
  /// Childless DisplayObjects, like [GShape] and [GBitmap], have their own
  /// Paint() so no need to use an expensive saveLayer().
  bool allowSaveLayer = false;

  GRect? getFilterBounds([GRect? layerBounds, ui.Paint? alphaPaint]) {
    layerBounds ??= getBounds($parent);
    if ($filters == null || $filters!.isEmpty) {
      return layerBounds;
    }
    layerBounds = layerBounds!.clone();
    GRect? resultBounds;
    for (var filter in $filters!) {
      resultBounds ??= layerBounds.clone();
      if (alphaPaint != null) {
        filter.update();
      }
      filter.expandBounds(layerBounds, resultBounds);
      if (alphaPaint != null) {
        filter.currentObject = this;
        filter.resolvePaint(alphaPaint);
        filter.currentObject = null;
      }
    }
    return resultBounds;
  }

  ui.Paint filterPaint = ui.Paint();

  /// to create the rectangle to save the layer and optimize rendering.
  /// active by default.
  bool $useSaveLayerBounds = true;

  /// Do not override this method as it applies the basic
  /// transformations. Override $applyPaint() if you wanna use
  /// `Canvas` directly.
  void paint(ui.Canvas canvas) {
    if (!$hasVisibleArea || !visible) {
      return;
    }
    $onPreTransform?.dispatch(canvas);
    final hasScale = _scaleX != 1 || _scaleY != 1;
    final hasTranslate = _x != 0 || _y != 0;
    final hasPivot = _pivotX != 0 || _pivotY != 0;
    final hasSkew = _skewX != 0 || _skewY != 0;
    final needSave = hasTranslate ||
        hasScale ||
        rotation != 0 ||
        hasPivot ||
        hasSkew ||
        _is3D;

    final $hasFilters = hasFilters;
    // final hasColorize = $colorize?.alpha > 0 ?? false;
    // var _saveLayer = this is DisplayObjectContainer &&
    //     (this as DisplayObjectContainer).hasChildren &&
    //     ($alpha != 1 || $hasColorize || $hasFilters);
    var saveLayer =
        allowSaveLayer && $alpha != 1 || $hasColorize || $hasFilters;
    // if (this is DisplayObjectContainer &&
    //     (this as DisplayObjectContainer).hasChildren) {
    // }

    final hasMask = mask != null || maskRect != null;
    final showDebugBounds =
        DisplayBoundsDebugger.debugBoundsMode == DebugBoundsMode.internal &&
            ($debugBounds || DisplayBoundsDebugger.debugAll);

    GRect? cacheLocalBoundsRect;
    if (showDebugBounds || saveLayer) {
      // _cacheLocalBoundsRect = bounds.toNative();
      cacheLocalBoundsRect = bounds;
    }

    List<GComposerFilter>? composerFilters;
    var filterHidesObject = false;
    if (saveLayer) {
//       TODO: static painter seems to have some issues, try local var later.
      /// using local Painter now to avoid problems.
      final alphaPaint = filterPaint;
      if (alpha < 1) {
        alphaPaint.color = kColorBlack.withOpacity(alpha);
      }

      /// check colorize if it needs a unique Paint instead.
      alphaPaint.colorFilter = null;
      alphaPaint.imageFilter = null;
      alphaPaint.maskFilter = null;
      if ($hasColorize) {
        alphaPaint.colorFilter = ui.ColorFilter.mode(
          $colorize!,
          ui.BlendMode.srcATop,
        );
      }
      ui.Rect? nativeLayerBounds;
      var layerBounds = getBounds($parent);
      if ($hasFilters) {
        /// TODO: Find a common implementation for filter bounds.
        // layerBounds = getFilterBounds(layerBounds, alphaPaint);
        layerBounds = layerBounds!.clone();
        GRect? resultBounds;
        for (var filter in $filters!) {
          resultBounds ??= layerBounds.clone();
          filter.update();
          filter.expandBounds(layerBounds, resultBounds);
          if (filter is GComposerFilter) {
            composerFilters ??= <GComposerFilter>[];
            composerFilters.add(filter);
          } else {
            filter.currentObject = this;
            filter.resolvePaint(alphaPaint);
            filter.currentObject = null;
          }
        }
        layerBounds = resultBounds;
      }
      $debugLastLayerBounds = layerBounds;
      // canvas.saveLayer(layerBounds.toNative(), alphaPaint);
      if ($useSaveLayerBounds) {
        nativeLayerBounds = layerBounds!.toNative();
      }
      canvas.saveLayer(nativeLayerBounds, alphaPaint);
    }
    if (needSave) {
      // onPreTransform.dispatch();
      canvas.save();
      var m = transformationMatrix.toNative();
      if (_is3D) {
        /// TODO: experimental, just transforms
        final m2 = GMatrix().toNative();
        m2.setEntry(3, 2, 0.004);
        m2.translate(_pivotX, _pivotY);
        if (z != 0) {
          m2.translate(.0, .0, z);
        }
        m2.rotateX(_rotationX);
        m2.rotateY(_rotationY);
        m2.translate(-_pivotX, -_pivotY);
        m.multiply(m2);
      }
      canvas.transform(m.storage);
    }

    if (hasMask) {
      canvas.save();
      if (maskRect != null) {
        $applyMaskRect(canvas);
      } else {
        mask!.$applyPaint(canvas);
      }
    }

    if (composerFilters != null) {
      for (var filter in composerFilters) {
        if (filter.hideObject ||
            (filter is GDropShadowFilter && filter.innerShadow)) {
          filterHidesObject = true;
        }
        filter.currentObject = this;
        filter.process(canvas, $applyPaint);
        filter.currentObject = null;
      }
    }
    $onPrePaint?.dispatch(canvas);
    if (!filterHidesObject) {
      $applyPaint(canvas);
    }
    $onPostPaint?.dispatch(canvas);

    if (hasMask) {
      canvas.restore();
    }
    if (showDebugBounds) {
      final paint = $debugBoundsPaint ?? _debugPaint;
      final linePaint = paint.clone();
      linePaint.color = linePaint.color.withOpacity(.3);
      final rect = cacheLocalBoundsRect!.toNative();
      canvas.drawLine(rect.topLeft, rect.bottomRight, linePaint);
      canvas.drawLine(rect.topRight, rect.bottomLeft, linePaint);
      canvas.drawRect(rect, paint);
    }
    if (needSave) {
      canvas.restore();
    }
    if (saveLayer) {
      canvas.restore();
    }
  }

  static final ui.Paint _debugPaint = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..color = kColorMagenta
    ..strokeWidth = 1;

  ui.Paint? $debugBoundsPaint = _debugPaint.clone();

  /// override this method for custom drawing using Flutter's API.
  /// Access `$canvas` from here.
  /// Make sure to implement getBounds() and hitTest() as well.
  void $applyPaint(ui.Canvas canvas) {}

  @mustCallSuper
  void dispose() {
//    _stage = null;
    $parent = null;
    userData = null;
    name = null;
    $disposePointerSignals();
    $disposeDisplayListSignals();
    $disposeRenderSignals();
  }

  void removeFromParent([bool dispose = false]) {
    $parent?.removeChild(this, dispose);
  }

  /// internal
  void $setParent(GDisplayObjectContainer? value) {
    var ancestor = value;
    while (ancestor != this && ancestor != null) {
      ancestor = ancestor.$parent;
    }
    if (ancestor == this) {
      throw ArgumentError(
          'An object cannot be added as a child to itself or one '
          'of its children (or children\'s children, etc.)');
    } else {
      $parent = value;
    }
  }

  /// shortcut to scale proportionally
  double get scale => _scaleX;

  set scale(double value) {
    if (value == _scaleX) return;
    _scaleY = _scaleX = value;
    $setTransformationChanged();
  }

  // shortcut to set x / y transformation
  GDisplayObject setPosition(double x, double y) {
    _x = x;
    _y = y;
    $setTransformationChanged();
    return this;
  }

  // shortcut to set scaleX / scaleY transformation
  GDisplayObject setScale(double scaleX, [double? scaleY]) {
    _scaleX = scaleX;
    _scaleY = scaleY ?? scaleX;
    $setTransformationChanged();
    return this;
  }

  /// ---- capture texture feature ---
  /// When you create a picture it takes the current state of the DisplayObject.
  /// Beware to call this before applying any
  /// transformations (x, y, scale, etc) if you intend to use in it's "original"
  /// form.
  ui.Picture createPicture(
      [void Function(ui.Canvas)? prePaintCallback,
      void Function(ui.Canvas)? postPaintCallback]) {
    final r = ui.PictureRecorder();
    final c = ui.Canvas(r);
    prePaintCallback?.call(c);
    paint(c);
    postPaintCallback?.call(c);
    return r.endRecording();
  }

  Future<GTexture> createImageTexture([
    bool adjustOffset = true,
    double resolution = 1,
    GRect? rect,
  ]) async {
    final img = await createImage(adjustOffset, resolution, rect);
    var tx = GTexture.fromImage(img, resolution);
    tx.pivotX = bounds!.x;
    tx.pivotY = bounds!.y;
    return tx;
  }

  Future<ui.Image> createImage([
    bool adjustOffset = true,
    double resolution = 1,
    GRect? rect,
  ]) async {
    rect ??= getFilterBounds(); //getBounds($parent);
    rect = rect!.clone();
    if (resolution != 1) {
      rect *= resolution;
    }
    final needsAdjust =
        (rect.left != 0 || rect.top != 0) && adjustOffset || resolution != 1;
    late ui.Picture picture;
    if (needsAdjust) {
      picture = createPicture((canvas) {
        if (adjustOffset) canvas.translate(-rect!.left, -rect.top);
        if (resolution != 1) canvas.scale(resolution);
      }, (canvas) {
        if (adjustOffset) canvas.restore();
        if (resolution != 1) canvas.restore();
      });
    } else {
      picture = createPicture();
    }
    final width = adjustOffset ? rect.width.toInt() : rect.right.toInt();
    final height = adjustOffset ? rect.height.toInt() : rect.bottom.toInt();
    final output = await picture.toImage(width, height);
    picture.dispose();
    return output;
  }

  GTexture createImageTextureSync([
    bool adjustOffset = true,
    double resolution = 1,
    GRect? rect,
  ]) {
    final img = createImageSync(adjustOffset, resolution, rect);
    var tx = GTexture.fromImage(img, resolution);
    tx.pivotX = bounds!.x;
    tx.pivotY = bounds!.y;
    return tx;
  }

  ui.Image createImageSync([
    bool adjustOffset = true,
    double resolution = 1,
    GRect? rect,
  ]) {
    rect ??= getFilterBounds();
    rect = rect!.clone();
    if (resolution != 1) {
      rect *= resolution;
    }
    final needsAdjust =
        (rect.left != 0 || rect.top != 0) && adjustOffset || resolution != 1;
    late ui.Picture picture;
    if (needsAdjust) {
      picture = createPicture((canvas) {
        if (adjustOffset) canvas.translate(-rect!.left, -rect.top);
        if (resolution != 1) canvas.scale(resolution);
      }, (canvas) {
        if (adjustOffset) canvas.restore();
        if (resolution != 1) canvas.restore();
      });
    } else {
      picture = createPicture();
    }
    final width = adjustOffset ? rect.width.toInt() : rect.right.toInt();
    final height = adjustOffset ? rect.height.toInt() : rect.bottom.toInt();
    final output = picture.toImageSync(width, height);
    picture.dispose();
    return output;
  }
}
