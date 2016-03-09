//
//  ImojiSDKUI
//
//  Created by Alex Hoang
//  Copyright (C) 2015 Imoji
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import UIKit
import ImojiSDKUI

enum IMCreateArtmojiViewSliderType: Int {
    case Color
    case BrushWidth
}

enum IMCreateArtmojiViewButtonType: Int {
    case Back
    case Cancel
    case Collection
    case Delete
    case Done
    case Draw
    case Flip
    case Undo
}

@objc public protocol IMCreateArtmojiViewDelegate {
    optional func userDidCancelCreateArtmojiView(view: IMCreateArtmojiView, dirty: Bool)
    optional func userDidFinishCreatingArtmoji(artmoji: UIImage, view: IMCreateArtmojiView)
    optional func userDidSelectImojiCollectionButtonFromArtmojiView(view: IMCreateArtmojiView)
    optional func artmojiView(view: IMCreateArtmojiView, didFinishLoadingImoji imoji: IMImojiObject)
}

public class IMCreateArtmojiView: UIView {

    // Required init properties
    public var sourceImage: UIImage!
    public var imageBundle: NSBundle
    private var session: IMImojiSession!

    // Transform variables
    private var touchCenter: CGPoint?
    private var rotationCenter: CGPoint?
    private var scaleCenter: CGPoint?
    private var lastPoint: CGPoint?

    // Artmoji Views
    private var backgroundView: UIImageView!
    private var backgroundGestureView: UIView!

    // Selected Imoji Views
    private var selectedImojiPreview: UIImageView!
    private var selectedImojis: [IMCreateArtmojiSelectedImojiView]

    private var _selectedImojiView: IMCreateArtmojiSelectedImojiView! {
        didSet {
            if _selectedImojiView != nil {
                _selectedImojiView.selected = true
                _selectedImojiView.showBorder = true

                session.renderImoji(_selectedImojiView.imoji!,
                        options: IMImojiObjectRenderingOptions(renderSize: IMImojiObjectRenderSize.SizeThumbnail)) { image, error in
                    if error == nil {
                        self.selectedImojiPreview.image = UIImage(CGImage: image!.CGImage!, scale: UIScreen.mainScreen().scale, orientation: UIImageOrientation.Up)
                        self.updateFlipImageButtonForSelectedImoji()
                    }
                }
            }

            // Hide imoji edit buttons when there isn't a selectedImoji i.e. when selectedImojis.count is 0
            deleteImojiButton.hidden = selectedImojiView == nil
            flipImojiButton.hidden = selectedImojiView == nil
            selectedImojiPreview.hidden = selectedImojiView == nil
        }
    }

    private var selectedImojiView: IMCreateArtmojiSelectedImojiView! {
        get {
            return _selectedImojiView
        }
        set {
            if _selectedImojiView != newValue {
                if(_selectedImojiView != nil) {
                    _selectedImojiView.selected = false
                    _selectedImojiView.showBorder = false
                }

                _selectedImojiView = newValue
            }
        }
    }

    // Drawing mode
    private var brushColorPreview: UIButton!
    private var drawingCanvasView: UIImageView!
    private var backButton: UIButton!
    private var undoButton: UIButton!
    private var brushSizeSlider: UISlider!
    private var colorSlider: IMColorSlider!
    private var drawnImages: [UIImage]
    private var hue: CGFloat
    private var brushWidth: CGFloat
    private var roundedWhiteBorderSize: CGFloat
    private var roundedBlackBorderSize: CGFloat
    private var swiped: Bool
    var capturedImageOrientation: UIImageOrientation

    // Top buttons
    private var cancelButton: UIButton!
    private var flipImojiButton: UIButton!

    // Bottom buttons
    var shareButton: UIButton!
    private var imojiCollectionButton: UIButton!
    private var deleteImojiButton: UIButton!
    private var drawButton: UIButton!

    // Delegate object
    public var delegate: IMCreateArtmojiViewDelegate?

    // MARK: - Object lifecycle
    public init(session: IMImojiSession, sourceImage: UIImage, imageBundle: NSBundle) {
        self.session = session
        self.sourceImage = sourceImage
        self.imageBundle = imageBundle

        selectedImojis = [IMCreateArtmojiSelectedImojiView]()

        // Drawing
        drawnImages = [UIImage]()
        swiped = false
        hue = 0
        brushWidth = 10.0
        roundedWhiteBorderSize = 4.0
        roundedBlackBorderSize = 5.0
        
        capturedImageOrientation = UIImageOrientation.Up

        super.init(frame: CGRectZero)

        setup()
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View lifecycle
    private func setup() {
        backgroundColor = UIColor(red: 48.0 / 255.0, green: 48.0 / 255.0, blue: 48.0 / 255.0, alpha: 1.0)

        // Set up top buttons
        deleteImojiButton = UIButton(type: UIButtonType.Custom)
        deleteImojiButton.setImage(UIImage(named: "Artmoji-Delete-Imoji"), forState: UIControlState.Normal)
        deleteImojiButton.addTarget(self, action: "buttonTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        deleteImojiButton.tag = IMCreateArtmojiViewButtonType.Delete.rawValue
        deleteImojiButton.hidden = true

        drawButton = UIButton(type: UIButtonType.Custom)
        drawButton.setImage(UIImage(named: "Artmoji-Draw"), forState: UIControlState.Normal)
        drawButton.addTarget(self, action: "buttonTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        drawButton.tag = IMCreateArtmojiViewButtonType.Draw.rawValue

        flipImojiButton = UIButton(type: UIButtonType.Custom)
        flipImojiButton.setImage(UIImage(named: "Artmoji-Flip-Imoji"), forState: UIControlState.Normal)
        flipImojiButton.addTarget(self, action: "buttonTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        flipImojiButton.tag = IMCreateArtmojiViewButtonType.Flip.rawValue
        flipImojiButton.hidden = true

        // Preview of currently selected imoji
        selectedImojiPreview = UIImageView()
        selectedImojiPreview.contentMode = UIViewContentMode.ScaleAspectFit
        selectedImojiPreview.hidden = true

        // Set up bottom buttons
        cancelButton = UIButton(type: UIButtonType.Custom)
        cancelButton.setImage(UIImage(named: "Artmoji-Cancel"), forState: UIControlState.Normal)
        cancelButton.addTarget(self, action: "buttonTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        cancelButton.tag = IMCreateArtmojiViewButtonType.Cancel.rawValue

        shareButton = UIButton(type: UIButtonType.Custom)
        shareButton.setImage(UIImage(named: "Artmoji-Share"), forState: UIControlState.Normal)
        shareButton.addTarget(self, action: "buttonTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        shareButton.tag = IMCreateArtmojiViewButtonType.Done.rawValue

        // Draw the plus image on top of the circle image and center it horizontally and vertically
        let circleImage = UIImage(named: "Artmoji-Circle")!
        let plusImage = UIImage(named: "Artmoji-Add-Imoji")!
        let imojiCollectionImage = IMDrawingUtils().drawImage(image: plusImage, withinImage: circleImage,
            atPoint: CGPointMake((circleImage.size.width - plusImage.size.width) / 2.0, (circleImage.size.height - plusImage.size.height) / 2.0))
        
        imojiCollectionButton = UIButton(type: UIButtonType.Custom)
        imojiCollectionButton.setImage(imojiCollectionImage, forState: UIControlState.Normal)
        imojiCollectionButton.addTarget(self, action: "buttonTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        imojiCollectionButton.tag = IMCreateArtmojiViewButtonType.Collection.rawValue

        // Set up drawing mode buttons
        backButton = UIButton(type: UIButtonType.Custom)
        backButton.setImage(UIImage(named: "Artmoji-Draw-Back"), forState: UIControlState.Normal)
        backButton.addTarget(self, action: "buttonTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        backButton.tag = IMCreateArtmojiViewButtonType.Back.rawValue
        backButton.hidden = true

        undoButton = UIButton(type: UIButtonType.Custom)
        undoButton.setImage(UIImage(named: "Artmoji-Draw-Undo"), forState: UIControlState.Normal)
        undoButton.addTarget(self, action: "buttonTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        undoButton.tag = IMCreateArtmojiViewButtonType.Undo.rawValue
        undoButton.hidden = true

        brushColorPreview = UIButton(type: UIButtonType.Custom)
        brushColorPreview.addTarget(self, action: "buttonTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        brushColorPreview.tag = IMCreateArtmojiViewButtonType.Draw.rawValue
        brushColorPreview.frame = CGRectMake(0, 0, IMArtmojiConstants.BrushColorPreviewWidthHeight, IMArtmojiConstants.BrushColorPreviewWidthHeight)
        brushColorPreview.hidden = true

        #if !NOT_PHOTO_EXTENSION
        cancelButton.hidden = true
        shareButton.hidden = true
        #endif

        // Artmoji view
        backgroundView = UIImageView(image: sourceImage)
        backgroundView.contentMode = UIViewContentMode.ScaleAspectFill
        backgroundView.userInteractionEnabled = true

        // Background gestures
        backgroundGestureView = UIView()
        backgroundGestureView.userInteractionEnabled = true

        // Drawing view
        drawingCanvasView = UIImageView()

        brushSizeSlider = UISlider()
        brushSizeSlider.minimumValue = Float(IMArtmojiConstants.MinimumBrushSize)
        brushSizeSlider.maximumValue = Float(IMArtmojiConstants.MaximumBrushSize)
        brushSizeSlider.value = Float(brushWidth)
        brushSizeSlider.transform = CGAffineTransformMakeRotation(CGFloat(M_PI_2))
        brushSizeSlider.addTarget(self, action: "sliderValueChanged:", forControlEvents: UIControlEvents.ValueChanged)
        brushSizeSlider.tag = IMCreateArtmojiViewSliderType.BrushWidth.rawValue
        brushSizeSlider.hidden = true

        colorSlider = IMColorSlider()
        colorSlider.addTarget(self, action: "sliderValueChanged:", forControlEvents: UIControlEvents.ValueChanged)
        colorSlider.tag = IMCreateArtmojiViewSliderType.Color.rawValue
        colorSlider.vertical = true
        colorSlider.hidden = true

        // Add subviews
        addSubview(backgroundView)
        addSubview(backgroundGestureView)
        addSubview(drawingCanvasView)

        // draw
        addSubview(backButton)
        addSubview(undoButton)
        addSubview(brushColorPreview)
        addSubview(brushSizeSlider)
        addSubview(colorSlider)

        // top
        addSubview(deleteImojiButton)
        addSubview(selectedImojiPreview)
        addSubview(flipImojiButton)
        addSubview(drawButton)

        // bottom
        addSubview(cancelButton)
        addSubview(shareButton)
        addSubview(imojiCollectionButton)

        // View constraints
        backgroundView.mas_makeConstraints { make in
            make.edges.equalTo()(self)
        }

        backgroundGestureView.mas_makeConstraints { make in
            make.edges.equalTo()(self)
        }

        drawingCanvasView.mas_makeConstraints { make in
            make.edges.equalTo()(self)
        }

        // top button constraints
        deleteImojiButton.mas_makeConstraints { make in
            make.top.equalTo()(self).offset()(IMArtmojiConstants.DefaultButtonTopOffset)
            make.left.equalTo()(self).offset()(IMArtmojiConstants.CreateArtmojiViewTopButtonEdgeOffset)
        }
        
        selectedImojiPreview.mas_makeConstraints { make in
            make.top.equalTo()(self).offset()(23)
            make.left.equalTo()(self.deleteImojiButton.mas_right).offset()(IMArtmojiConstants.CreateArtmojiViewTopButtonSpacing)
            make.height.equalTo()(IMArtmojiConstants.DefaultButtonItemWidthHeight)
            make.width.equalTo()(IMArtmojiConstants.DefaultButtonItemWidthHeight)
        }
        
        flipImojiButton.mas_makeConstraints { make in
            make.top.equalTo()(self).offset()(IMArtmojiConstants.DefaultButtonTopOffset)
            make.left.equalTo()(self.selectedImojiPreview.mas_right).offset()(IMArtmojiConstants.CreateArtmojiViewTopButtonSpacing)
        }
        
        drawButton.mas_makeConstraints { make in
            make.top.equalTo()(self).offset()(IMArtmojiConstants.DefaultButtonTopOffset)
            make.right.equalTo()(self).offset()(-IMArtmojiConstants.CreateArtmojiViewTopButtonEdgeOffset)
        }

        // bottom button constraints
        cancelButton.mas_makeConstraints { make in
            make.bottom.equalTo()(self).offset()(-36)
            make.left.equalTo()(self).offset()(IMArtmojiConstants.CreateArtmojiViewBottomButtonEdgeOffset)
        }
        
        shareButton.mas_makeConstraints { make in
            make.bottom.equalTo()(self).offset()(-34)
            make.right.equalTo()(self).offset()(-IMArtmojiConstants.CreateArtmojiViewBottomButtonEdgeOffset)
        }
        
        imojiCollectionButton.mas_makeConstraints { make in
            make.bottom.equalTo()(self).offset()(-IMArtmojiConstants.CaptureButtonBottomOffset)
            make.centerX.equalTo()(self)
        }

        // Drawing mode constraints
        backButton.mas_makeConstraints { make in
            make.top.equalTo()(self).offset()(IMArtmojiConstants.CreateArtmojiViewTopButtonTopOffset)
            make.left.equalTo()(self).offset()(IMArtmojiConstants.CreateArtmojiViewTopButtonEdgeOffset)
        }
        
        brushColorPreview.mas_makeConstraints { make in
            make.top.equalTo()(self).offset()(IMArtmojiConstants.DefaultButtonTopOffset)
            make.right.equalTo()(self).offset()(-IMArtmojiConstants.CreateArtmojiViewTopButtonEdgeOffset)
        }
        
        undoButton.mas_makeConstraints { make in
            make.top.equalTo()(self).offset()(IMArtmojiConstants.CreateArtmojiViewTopButtonTopOffset)
            make.right.equalTo()(self.brushColorPreview.mas_left).offset()(-30)
        }

        colorSlider.mas_makeConstraints { make in
            make.top.equalTo()(self.brushColorPreview.mas_bottom).offset()(75)
            make.right.equalTo()(self).offset()(50)
            make.width.equalTo()(IMArtmojiConstants.SliderWidth)
        }

        brushSizeSlider.mas_makeConstraints { make in
            make.top.equalTo()(self.colorSlider.mas_bottom).offset()(CGFloat(IMArtmojiConstants.SliderWidth))
            make.right.equalTo()(self).offset()(50)
            make.width.equalTo()(IMArtmojiConstants.SliderWidth)
        }

        setupGestureRecognizers()
    }

    private func setupGestureRecognizers() {
        let panRecognizer = UIPanGestureRecognizer(target: self, action: "imojiPanned:")
        panRecognizer.cancelsTouchesInView = false
        panRecognizer.delegate = self

        let rotationRecognizer = UIRotationGestureRecognizer(target: self, action: "imojiRotated:")
        rotationRecognizer.cancelsTouchesInView = false
        rotationRecognizer.delegate = self

        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: "imojiPinched:")
        pinchRecognizer.cancelsTouchesInView = false
        pinchRecognizer.delegate = self

        backgroundGestureView.addGestureRecognizer(panRecognizer)
        backgroundGestureView.addGestureRecognizer(rotationRecognizer)
        backgroundGestureView.addGestureRecognizer(pinchRecognizer)
        
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: "drawingCanvasLongPressed:")
        longPressRecognizer.minimumPressDuration = 0.2
        longPressRecognizer.cancelsTouchesInView = false
        longPressRecognizer.delegate = self
        
        drawingCanvasView.addGestureRecognizer(longPressRecognizer)
    }

    // MARK: - Artmoji editor button logic
    func buttonTapped(sender: UIButton) {
        switch sender.tag {
            case IMCreateArtmojiViewButtonType.Back.rawValue, IMCreateArtmojiViewButtonType.Draw.rawValue:
                lastPoint = CGPointZero

                // Set drawing state
                let drawing = !drawingCanvasView.userInteractionEnabled
                drawingCanvasView.userInteractionEnabled = drawing

                // Show/Hide buttons/sliders
                brushSizeSlider.hidden = !drawing
                colorSlider.hidden = !drawing
                backButton.hidden = !drawing
                undoButton.hidden = !drawing
                brushColorPreview.hidden = !drawing

                // Toggle only when there is a selected imoji
                if selectedImojiView != nil {
                    deleteImojiButton.hidden = drawing
                    selectedImojiPreview.hidden = drawing
                    flipImojiButton.hidden = drawing
                }
                
                drawButton.hidden = drawing
                #if NOT_PHOTO_EXTENSION
                cancelButton.hidden = drawing
                #endif

                // Show/Hide the background gesture view to avoid manipulating both the brush and the imoji
                backgroundGestureView.hidden = drawing

                for imoji in selectedImojis {
                    imoji.userInteractionEnabled = !drawing
                }

                if brushColorPreview.imageForState(UIControlState.Normal) == nil {
                    renderBrushPreview()
                }
                break
            case IMCreateArtmojiViewButtonType.Cancel.rawValue:
                delegate?.userDidCancelCreateArtmojiView?(self, dirty: !selectedImojis.isEmpty || !drawnImages.isEmpty)
                break
            case IMCreateArtmojiViewButtonType.Collection.rawValue:
                delegate?.userDidSelectImojiCollectionButtonFromArtmojiView?(self)
                if drawingCanvasView.userInteractionEnabled {
                    drawButton.sendActionsForControlEvents(UIControlEvents.TouchUpInside)
                }
                break
            case IMCreateArtmojiViewButtonType.Delete.rawValue:
                if selectedImojiView != nil {
                    selectedImojiView.removeFromSuperview()

                    let index = selectedImojis.indexOf(selectedImojiView)!
                    selectedImojis.removeAtIndex(index)
                    selectedImojiView = selectedImojis.last
                }
                break
            case IMCreateArtmojiViewButtonType.Done.rawValue:
                let image = drawCompositionImage()
                delegate?.userDidFinishCreatingArtmoji?(image, view: self)
                break
            case IMCreateArtmojiViewButtonType.Flip.rawValue:
                if selectedImojiView != nil {
                    selectedImojiView.flipHorizontal()
                    updateFlipImageButtonForSelectedImoji()
                }
                break
            case IMCreateArtmojiViewButtonType.Undo.rawValue:
                drawnImages.popLast()
                drawingCanvasView.image = drawnImages.last
                break
            default:
                break
        }
    }

    func updateFlipImageButtonForSelectedImoji() {
        var image = UIImage(named: "Artmoji-Flip-Imoji")!
        if selectedImojiView.flipped {
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            let context = UIGraphicsGetCurrentContext()

            CGContextTranslateCTM(context, image.size.width, 0)
            CGContextScaleCTM(context, -1, 1)
            image.drawInRect(CGRectMake(0, 0, image.size.width, image.size.height))

            image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
        }

        flipImojiButton.setImage(image, forState: UIControlState.Normal)
    }

    // MARK: - Drawing slider logic
    func sliderValueChanged(sender: UISlider) {
        switch sender.tag {
            case IMCreateArtmojiViewSliderType.BrushWidth.rawValue:
                brushWidth = CGFloat(sender.value)
                break
            case IMCreateArtmojiViewSliderType.Color.rawValue:
                hue = CGFloat(sender.value)
                break
            default:
                break
        }

        renderBrushPreview()
    }

    // MARK: - Touch overrides
    func handleTouches(touches: Set<UITouch>) {
        self.touchCenter = CGPointZero
        if touches.count < 2 {
            return
        }

        for touch in touches {
            let viewForGesture = selectedImojiView ?? touch.view
            let touchLocation = touch.locationInView(viewForGesture)
            self.touchCenter = CGPointMake(self.touchCenter!.x + touchLocation.x, self.touchCenter!.y + touchLocation.y)
        }

        self.touchCenter = CGPointMake(self.touchCenter!.x / CGFloat(touches.count), self.touchCenter!.y / CGFloat(touches.count))
    }

    override public func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if drawingCanvasView.userInteractionEnabled {
            swiped = false
            if let touch = touches.first {
                lastPoint = touch.locationInView(self)
            }
        } else {
            handleTouches(event!.allTouches()!)
        }
    }

    override public func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if drawingCanvasView.userInteractionEnabled {
            UIView.animateWithDuration(0.2, delay: 0.2, options: UIViewAnimationOptions.CurveEaseOut, animations: { animate in
                // Fade out top and bottom buttons
                self.imojiCollectionButton.alpha = 0
                self.shareButton.alpha = 0
                self.backButton.alpha = 0
                self.undoButton.alpha = 0
                self.brushColorPreview.alpha = 0
            }, completion: nil)
            swiped = true
            if let touch = touches.first {
                let currentPoint = touch.locationInView(self)
                drawLine(lastPoint!, toPoint: currentPoint)
                lastPoint = currentPoint
            }
        } else {
            handleTouches(event!.allTouches()!)
        }
    }

    override public func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if drawingCanvasView.userInteractionEnabled {
            if !swiped {
                drawLine(lastPoint!, toPoint: lastPoint!)
            }

            UIView.animateWithDuration(0.2, delay: 0, options: UIViewAnimationOptions.CurveEaseIn, animations: { animate in
                // Fade in top and bottom buttons
                self.imojiCollectionButton.alpha = 1.0
                self.shareButton.alpha = 1.0
                self.backButton.alpha = 1.0
                self.undoButton.alpha = 1.0
                self.brushColorPreview.alpha = 1.0
            }, completion: nil)

            drawnImages.append(drawingCanvasView.image!)
        } else {
            handleTouches(event!.allTouches()!)
        }
    }

    // MARK: - Gestures
    func imojiTapped(recognizer: UITapGestureRecognizer) {
        if recognizer.view!.isKindOfClass(IMCreateArtmojiSelectedImojiView) {
            insertSubview(recognizer.view!, belowSubview: drawingCanvasView)
            selectedImojiView = recognizer.view as! IMCreateArtmojiSelectedImojiView
            selectedImojis.removeAtIndex(selectedImojis.indexOf(selectedImojiView)!)
            selectedImojis.append(selectedImojiView)
        }
    }

    func imojiPanned(recognizer: UIPanGestureRecognizer) {
        // when the user pans an imoji they are selecting it for editing
        if recognizer.view!.isKindOfClass(IMCreateArtmojiSelectedImojiView) {
            insertSubview(recognizer.view!, belowSubview: drawingCanvasView)
            selectedImojiView = recognizer.view as! IMCreateArtmojiSelectedImojiView
            selectedImojis.removeAtIndex(selectedImojis.indexOf(selectedImojiView)!)
            selectedImojis.append(selectedImojiView)
        }

        if let viewForGesture = selectedImojiView {
            let translation = recognizer.translationInView(viewForGesture)
            let transform = CGAffineTransformTranslate(viewForGesture.transform, translation.x, translation.y)
            viewForGesture.transform = transform
            recognizer.setTranslation(CGPointZero, inView: viewForGesture)
        }
    }

    func imojiRotated(recognizer: UIRotationGestureRecognizer) {
        if let viewForGesture = selectedImojiView {
            if recognizer.state == UIGestureRecognizerState.Began {
                self.rotationCenter = self.touchCenter
            }

            let deltaX = self.rotationCenter!.x - viewForGesture.bounds.size.width / 2
            let deltaY = self.rotationCenter!.y - viewForGesture.bounds.size.height / 2

            var transform = CGAffineTransformTranslate(viewForGesture.transform, deltaX, deltaY)
            transform = CGAffineTransformRotate(transform, recognizer.rotation)
            transform = CGAffineTransformTranslate(transform, -deltaX, -deltaY)
            viewForGesture.transform = transform
            recognizer.rotation = 0
        }
    }

    func imojiPinched(recognizer: UIPinchGestureRecognizer) {
        if let viewForGesture = selectedImojiView {
            if recognizer.state == UIGestureRecognizerState.Began {
                self.scaleCenter = self.touchCenter
            }

            let deltaX = self.scaleCenter!.x - viewForGesture.bounds.size.width / 2.0
            let deltaY = self.scaleCenter!.y - viewForGesture.bounds.size.height / 2.0

            var transform = CGAffineTransformTranslate(viewForGesture.transform, deltaX, deltaY)
            transform = CGAffineTransformScale(transform, recognizer.scale, recognizer.scale)
            transform = CGAffineTransformTranslate(transform, -deltaX, -deltaY)
            viewForGesture.transform = transform

            recognizer.scale = 1
        }
    }
    
    func drawingCanvasLongPressed(recognizer: UILongPressGestureRecognizer) {
        UIView.animateWithDuration(0.2, delay: 0, options: UIViewAnimationOptions.CurveEaseOut, animations: { animate in
            // Fade out top and bottom buttons
            self.imojiCollectionButton.alpha = 0
            self.shareButton.alpha = 0
            self.backButton.alpha = 0
            self.undoButton.alpha = 0
            self.brushColorPreview.alpha = 0
        }, completion: nil)
    }

    // MARK: - Image & Imoji logic
    // Renders the imoji and adds it onto the view with its gesture recognizers
    func addImoji(imoji: IMImojiObject) {
        let selectedImojiView = IMCreateArtmojiSelectedImojiView(imoji: imoji, session: self.session)

        if selectedImojis.count == 0 {
            insertSubview(selectedImojiView, aboveSubview: backgroundGestureView)
        } else {
            insertSubview(selectedImojiView, aboveSubview: selectedImojis.last!)
        }

        self.selectedImojiView = selectedImojiView

        let panRecognizer = UIPanGestureRecognizer(target: self, action: "imojiPanned:")
        panRecognizer.cancelsTouchesInView = false
        panRecognizer.delegate = self

        let rotationRecognizer = UIRotationGestureRecognizer(target: self, action: "imojiRotated:")
        rotationRecognizer.cancelsTouchesInView = false
        rotationRecognizer.delegate = self

        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: "imojiPinched:")
        pinchRecognizer.cancelsTouchesInView = false
        pinchRecognizer.delegate = self

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: "imojiTapped:")
        tapGestureRecognizer.cancelsTouchesInView = false
        tapGestureRecognizer.delegate = self

        selectedImojiView.userInteractionEnabled = true
        selectedImojiView.addGestureRecognizer(panRecognizer)
        selectedImojiView.addGestureRecognizer(rotationRecognizer)
        selectedImojiView.addGestureRecognizer(pinchRecognizer)
        selectedImojiView.addGestureRecognizer(tapGestureRecognizer)

        selectedImojis.append(selectedImojiView)
        
        delegate?.artmojiView?(self, didFinishLoadingImoji: imoji)
    }

    // Renders the artmoji and returns an image
    func drawCompositionImage() -> UIImage {
        let imageSize = CGSizeMake(backgroundView.bounds.size.width, backgroundView.bounds.size.height)
        UIGraphicsBeginImageContextWithOptions(imageSize, false, 0.0)
        let context = UIGraphicsGetCurrentContext()

        // Save background image
        CGContextSaveGState(context)
        CGContextTranslateCTM(context, backgroundView.center.x, backgroundView.center.y)
        CGContextConcatCTM(context, backgroundView.transform)
        CGContextTranslateCTM(context,
                -backgroundView.bounds.size.width * backgroundView.layer.anchorPoint.x,
                -backgroundView.bounds.size.height * backgroundView.layer.anchorPoint.y)
        backgroundView.layer.renderInContext(context!)
        CGContextRestoreGState(context)

        // Save all imojis added to the backgroundView
        for imoji in selectedImojis {
            CGContextSaveGState(context)
            CGContextTranslateCTM(context, imoji.center.x, imoji.center.y)
            CGContextConcatCTM(context, imoji.transform)
            CGContextTranslateCTM(context, -imoji.bounds.size.width * imoji.layer.anchorPoint.x, -imoji.bounds.size.height * imoji.layer.anchorPoint.y)
            imoji.layer.renderInContext(context!)
            CGContextRestoreGState(context)
        }

        // Save drawing
        CGContextSaveGState(context)
        CGContextTranslateCTM(context, drawingCanvasView.center.x, drawingCanvasView.center.y)
        CGContextConcatCTM(context, drawingCanvasView.transform)
        CGContextTranslateCTM(context,
                -drawingCanvasView.bounds.size.width * drawingCanvasView.layer.anchorPoint.x,
                -drawingCanvasView.bounds.size.height * drawingCanvasView.layer.anchorPoint.y)
        drawingCanvasView.layer.renderInContext(context!)
        CGContextRestoreGState(context)

        let watermarkImage = UIImage(named:"Artmoji-Share-Watermark")!
        switch capturedImageOrientation {
            case UIImageOrientation.Left:
                let orientatedImage = UIImage(CGImage: watermarkImage.CGImage!, scale: 2.5, orientation: UIImageOrientation.Right)
                orientatedImage.drawInRect(CGRectMake(0, imageSize.height - orientatedImage.size.height, orientatedImage.size.width, orientatedImage.size.height))
                break
            case UIImageOrientation.Right:
                let orientatedImage = UIImage(CGImage: watermarkImage.CGImage!, scale: 2.5, orientation: UIImageOrientation.Left)
                orientatedImage.drawInRect(CGRectMake(imageSize.width - orientatedImage.size.width, 0, orientatedImage.size.width, orientatedImage.size.height))
                break
            case UIImageOrientation.Down:
                let orientatedImage = UIImage(CGImage: watermarkImage.CGImage!, scale: 2.5, orientation: capturedImageOrientation)
                orientatedImage.drawInRect(CGRectMake(0, 0, orientatedImage.size.width, orientatedImage.size.height))
                break
            default:
                watermarkImage.drawInRect(CGRectMake(imageSize.width - watermarkImage.size.width, imageSize.height - watermarkImage.size.height, watermarkImage.size.width, watermarkImage.size.height))
                break
        }

        let img = capturedImageOrientation == UIImageOrientation.Up ? UIGraphicsGetImageFromCurrentImageContext()
                                                                    : UIImage(CGImage: UIGraphicsGetImageFromCurrentImageContext().CGImage!, scale: 1.0, orientation: capturedImageOrientation)
        UIGraphicsEndImageContext()
        return img
    }

    // Render the preview image for the brush upon entering drawing mode the first time or
    // changing color/size of the brush
    func renderBrushPreview() {
        // Draw the color preview of the brush
        brushColorPreview.setImage(drawRoundedPreviewImageInFrame(CGRectMake(0, 0, IMArtmojiConstants.BrushColorPreviewWidthHeight, IMArtmojiConstants.BrushColorPreviewWidthHeight),
            lineWidth: IMArtmojiConstants.MaximumBrushSize, sizeRatio: 0), forState: UIControlState.Normal)

        // Draw the pencil on top of the preview and center it horizontally
        let pencilImage = UIImage(named: "Artmoji-Draw")!
        brushColorPreview.setImage(IMDrawingUtils().drawImage(image: pencilImage, withinImage: brushColorPreview.imageForState(UIControlState.Normal)!,
            atPoint: CGPointMake(brushColorPreview.imageForState(UIControlState.Normal)!.size.width / 2.0, 0)),
            forState: UIControlState.Normal)

        // Draw thumb image used for brushSizeSlider
        let brushSizeThumbImage = drawRoundedPreviewImageInFrame(CGRectMake(0, 0, IMArtmojiConstants.BrushSizeThumbWidthHeight, IMArtmojiConstants.BrushSizeThumbWidthHeight),
                lineWidth: IMArtmojiConstants.BrushSizePreviewSize, sizeRatio: IMArtmojiConstants.BrushSizePreviewSize / IMArtmojiConstants.MaximumBrushSize)
        brushSizeSlider.setThumbImage(brushSizeThumbImage, forState: UIControlState.Normal)
        brushSizeSlider.setThumbImage(brushSizeThumbImage, forState: UIControlState.Highlighted)
    }

    // Draws a line with color and size of the brush from point to point
    func drawLine(fromPoint: CGPoint, toPoint: CGPoint) {
        UIGraphicsBeginImageContext(frame.size)
        let context = UIGraphicsGetCurrentContext()
        drawingCanvasView.image?.drawInRect(CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height))

        CGContextMoveToPoint(context, fromPoint.x, fromPoint.y)
        CGContextAddLineToPoint(context, toPoint.x, toPoint.y)
        CGContextSetLineCap(context, CGLineCap.Round)
        CGContextSetLineWidth(context, brushWidth)
        CGContextSetStrokeColorWithColor(context, UIColor(hue: self.hue, saturation: 1.0, brightness: 1.0, alpha: 1.0).CGColor)
        CGContextSetBlendMode(context, CGBlendMode.Normal)
        CGContextStrokePath(context)

        drawingCanvasView.image = UIGraphicsGetImageFromCurrentImageContext()
        drawingCanvasView.alpha = 1.0
        UIGraphicsEndImageContext()
    }

    // Renders a rounded preview image of the brush within a frame with a black/white border
    // Preview changes color and size. Size changes happen within the border and uses a sizeRatio.
    // If the sizeRatio is 0 then the preview image won't be scaled
    func drawRoundedPreviewImageInFrame(frame: CGRect, lineWidth: CGFloat, sizeRatio: CGFloat) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(frame.size, false, 0.0)
        let context = UIGraphicsGetCurrentContext()

        // Draw the black border
        CGContextMoveToPoint(context, frame.size.width / 2.0, frame.size.height / 2.0)
        CGContextAddLineToPoint(context, frame.size.width / 2.0, frame.size.height / 2.0)
        CGContextSetLineCap(context, CGLineCap.Round)
        CGContextSetLineWidth(context, lineWidth + roundedBlackBorderSize)
        CGContextSetStrokeColorWithColor(context, UIColor(red: 0, green: 0, blue: 0, alpha: 0.8).CGColor)
        CGContextStrokePath(context)

        // Draw the white border
        CGContextMoveToPoint(context, frame.size.width / 2.0, frame.size.height / 2.0)
        CGContextAddLineToPoint(context, frame.size.width / 2.0, frame.size.height / 2.0)
        CGContextSetLineWidth(context, lineWidth + roundedWhiteBorderSize)
        CGContextSetStrokeColorWithColor(context, UIColor.whiteColor().CGColor)
        CGContextStrokePath(context)

        // Draw the preview within the borders
        CGContextMoveToPoint(context, frame.size.width / 2.0, frame.size.height / 2.0)
        CGContextAddLineToPoint(context, frame.size.width / 2.0, frame.size.height / 2.0)
        // When sizeRatio is not 0, multiply the current brush width by the ratio
        // Otherwise, set it to the provided lineWidth
        CGContextSetLineWidth(context, sizeRatio == 0 ? lineWidth : brushWidth * sizeRatio)
        CGContextSetStrokeColorWithColor(context, UIColor(hue: self.hue, saturation: 1.0, brightness: 1.0, alpha: 1.0).CGColor)
        CGContextStrokePath(context)

        let previewImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return previewImage
    }
}

// MARK: - UIGestureRecognizerDelegate
extension IMCreateArtmojiView: UIGestureRecognizerDelegate {
    public func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}