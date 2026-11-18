import AppKit
import SkywriteCore

/// The background behind a note's text: soft edge or Liquid Glass, and the window shadow.
extension NoteController {
    func layoutGlass() {
        let staysClear = style.glassStyle == .liquidGlass && style.liquidGlassStaysClear
        if panel.keepsActiveAppearance != staysClear {
            panel.keepsActiveAppearance = staysClear
            // The glass picks up the window's look when it joins the window, so put it back in to apply the change now.
            liquidGlassView.removeFromSuperview()
            liquidGlassClipView.addSubview(liquidGlassView)
        }
        updateWindowShadow()
        let showsSoftEdge = style.glassStyle == .softEdge && style.showsBackground
        softEdgeView.isHidden = !showsSoftEdge
        liquidGlassClipView.isHidden = style.glassStyle != .liquidGlass
        switch style.glassStyle {
        case .softEdge:
            guard showsSoftEdge else { return }
            softEdgeView.alphaValue = style.glassStrength
            softEdgeView.frame = textView.frame.insetBy(dx: -NoteMetrics.frameGap, dy: -NoteMetrics.frameGap)
            softEdgeView.maskImage = Self.featheredMask(size: softEdgeView.frame.size, feather: NoteMetrics.softEdgeFeather)
        case .liquidGlass:
            let radius = NoteMetrics.liquidGlassCornerRadius * zoom
            liquidGlassClipView.frame = textView.frame
            liquidGlassClipView.layer?.cornerRadius = radius
            liquidGlassView.frame = liquidGlassClipView.bounds
            liquidGlassView.cornerRadius = radius
        }
    }

    /// The window shadow follows what the window draws, so it's worked out again once the note has redrawn at its new size.
    private func updateWindowShadow() {
        let showsShadow = style.glassStyle == .liquidGlass && style.liquidGlassShadow
        if panel.hasShadow != showsShadow {
            panel.hasShadow = showsShadow
        }
        guard showsShadow else { return }
        DispatchQueue.main.async { [weak panel] in
            panel?.invalidateShadow()
        }
    }

    static func featheredMask(size: CGSize, feather: CGFloat) -> NSImage? {
        let width = max(1, Int(size.width.rounded(.up)))
        let height = max(1, Int(size.height.rounded(.up)))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let inner = CGRect(x: 0, y: 0, width: width, height: height).insetBy(dx: feather, dy: feather)
        guard inner.width > 0, inner.height > 0 else { return nil }
        let offset = CGFloat(height) * 2
        context.setShadow(offset: CGSize(width: 0, height: -offset), blur: feather, color: CGColor(gray: 0, alpha: 1))
        context.addPath(CGPath(roundedRect: inner.offsetBy(dx: 0, dy: offset), cornerWidth: min(feather, inner.width / 2), cornerHeight: min(feather, inner.height / 2), transform: nil))
        context.fillPath()
        guard let image = context.makeImage() else { return nil }
        return NSImage(cgImage: image, size: size)
    }
}
