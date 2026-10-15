#!/usr/bin/env swift
import AppKit
import CoreText
import Foundation
import Darwin

func fail(_ message:String)->Never {
    FileHandle.standardError.write(Data(("UI_RENDER_FAILED: " + message + "\n").utf8))
    exit(1)
}

// Native Quartz/AppKit renderer. No third-party modules or scaled text screenshots.
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let root = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let assetRoot = root.appendingPathComponent("assets/design")
let previews = root.appendingPathComponent("previews")
try FileManager.default.createDirectory(at: previews, withIntermediateDirectories: true)
let fontURL = root.appendingPathComponent("assets/fonts/NotoSansSC.ttf")
guard FileManager.default.fileExists(atPath:fontURL.path) else {
    fail("Required bundled Noto font is missing: \(fontURL.path)")
}
guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as? [CTFontDescriptor],
      let descriptor = descriptors.first,
      let fontName = CTFontDescriptorCopyAttribute(descriptor,kCTFontNameAttribute) as? String,
      fontName.hasPrefix("NotoSansSC") else {
    fail("Bundled font is invalid or is not Noto Sans SC: \(fontURL.path)")
}
var fontRegistrationError:Unmanaged<CFError>?
guard CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &fontRegistrationError) else {
    let detail=fontRegistrationError.map { String(describing:$0.takeRetainedValue()) } ?? "Unknown CoreText error"
    fail("Could not register bundled Noto font: \(detail)")
}
let fontUsed = fontName
let scenes = try JSONSerialization.jsonObject(with:Data(contentsOf:assetRoot.appendingPathComponent("scenes.json"))) as! [[String:Any]]
func number(_ o:[String:Any],_ k:String)->CGFloat { (o[k] as? NSNumber)?.doubleValue ?? 0 }
func color(_ h:String)->CGColor {
    let n=UInt32(h.dropFirst(),radix:16)!; return CGColor(red:CGFloat((n>>16)&255)/255,green:CGFloat((n>>8)&255)/255,blue:CGFloat(n&255)/255,alpha:1)
}
func makeContext(_ w:Int,_ h:Int)->CGContext {
    CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
}
func makeFont(_ size:CGFloat,_ weight:String)->NSFont {
    let w = weight == "bold" ? 700 : weight == "semibold" ? 600 : 400
    let descriptor=CTFontDescriptorCreateWithNameAndSize(fontName as CFString,size)
    let varied=CTFontDescriptorCreateCopyWithVariation(descriptor,NSNumber(value:0x77676874),CGFloat(w))
    let ct=CTFontCreateWithFontDescriptor(varied,size,nil)
    return unsafeBitCast(ct,to:NSFont.self)
}
var metrics:[[String:Any]]=[]
func render(_ sc:[String:Any],_ scale:Int)->CGImage {
    let ctx=makeContext(640*scale,480*scale)
    ctx.translateBy(x:0,y:CGFloat(480*scale));ctx.scaleBy(x:CGFloat(scale),y:-CGFloat(scale))
    ctx.setAllowsAntialiasing(true);ctx.setShouldAntialias(true)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current=NSGraphicsContext(cgContext:ctx,flipped:true)
    for o in sc["ops"] as! [[String:Any]] {
        let k=o["kind"] as! String;let c=color(o["color"] as! String)
        let x=number(o,"x"),y=number(o,"y")
        ctx.setFillColor(c);ctx.setStrokeColor(c);ctx.setLineWidth(number(o,"sw"));ctx.setLineCap(.round);ctx.setLineJoin(.round)
        if k == "text" {
            let size=number(o,"size");let txt=o["text"] as! String;let font=makeFont(size,o["weight"] as! String)
            let ctFont=unsafeBitCast(font,to:CTFont.self)
            let attr=NSAttributedString(string:txt,attributes:[NSAttributedString.Key(kCTFontAttributeName as String):ctFont,NSAttributedString.Key(kCTForegroundColorAttributeName as String):c])
            let ctLine=CTLineCreateWithAttributedString(attr)
            ctx.saveGState();ctx.textMatrix=CGAffineTransform(scaleX:1,y:-1);ctx.textPosition=CGPoint(x:x,y:y+CTFontGetAscent(ctFont));CTLineDraw(ctLine,ctx);ctx.restoreGState()
            if scale == 1 { let d=attr.size();let ib=CTLineGetBoundsWithOptions(ctLine,.useGlyphPathBounds);let ink=CGRect(x:x+ib.minX,y:y+CTFontGetAscent(ctFont)-ib.maxY,width:ib.width,height:ib.height);let chars=Array(txt.utf16);var glyphs=Array(repeating:CGGlyph(0),count:chars.count);let ct=unsafeBitCast(font,to:CTFont.self);CTFontGetGlyphsForCharacters(ct,chars,&glyphs,chars.count);let missing=glyphs.enumerated().filter { $0.element == 0 && chars[$0.offset] != 32 };metrics.append(["page":sc["id"]!,"text":txt,"font_ascent":CTFontGetAscent(ctFont),"ink_bounds":[ink.minX,ink.minY,ink.width,ink.height],"ink_inside_24px_safe_frame":size<16 || (ink.minX>=24 && ink.maxX<=616 && ink.minY>=24 && ink.maxY<=456),"font":CTFontCopyPostScriptName(ct),"actual_wght":(CTFontCopyVariation(ct) as? [NSNumber:NSNumber])?[NSNumber(value:0x77676874)]?.doubleValue ?? -1,"missing_glyph_count":missing.count,"missing_glyph_utf16_indices":missing.map{$0.offset},"x":x,"y":y,"w":d.width,"h":d.height,"size":size,"weight":o["weight"]!,"inside_canvas":x+d.width<=640 && y+d.height<=480,"core_text_safe":size<16 || y<70 || (x>=24 && x+d.width<=616 && y>=24 && y+d.height<=456)]) }
        } else {
            let p=CGMutablePath()
            if k == "rect" {p.addRoundedRect(in:CGRect(x:x,y:y,width:number(o,"w"),height:number(o,"h")),cornerWidth:number(o,"r"),cornerHeight:number(o,"r"))}
            if k == "circle" {let r=number(o,"r");p.addEllipse(in:CGRect(x:x-r,y:y-r,width:r*2,height:r*2))}
            if k == "line" || k == "poly" { let pts=o["points"] as! [[NSNumber]];p.move(to:CGPoint(x:pts[0][0].doubleValue,y:pts[0][1].doubleValue));for pt in pts.dropFirst(){p.addLine(to:CGPoint(x:pt[0].doubleValue,y:pt[1].doubleValue))};if k == "poly"{p.closeSubpath()} }
            ctx.addPath(p)
            if k == "line"{ctx.strokePath()}else{ctx.fillPath()}
            if let stroke=o["stroke"] as? String {ctx.addPath(p);ctx.setStrokeColor(color(stroke));ctx.strokePath()}
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    return ctx.makeImage()!
}
func png(_ img:CGImage,_ url:URL)throws {
    let rep=NSBitmapImageRep(cgImage:img);try rep.representation(using:.png,properties:[:])!.write(to:url)
}
func ppm(_ img:CGImage,_ url:URL)throws {
    let data=img.dataProvider!.data!;let ptr=CFDataGetBytePtr(data)!;let stride=img.bytesPerRow
    var output=Data("P6\n640 480\n255\n".utf8)
    for y in 0..<480 {for x in 0..<640 {let p=y*stride+x*4;output.append(ptr[p]);output.append(ptr[p+1]);output.append(ptr[p+2])}}
    try output.write(to:url)
}
var natives:[CGImage]=[]
for sc in scenes {
    let id=sc["id"] as! String;let label="UI-"+String(id.suffix(2))
    let native=render(sc,1);natives.append(native)
    try png(native,previews.appendingPathComponent(label+".png"))
    try png(render(sc,2),previews.appendingPathComponent(label+"@2x.png"))
    try ppm(native,assetRoot.appendingPathComponent(id+".ppm"))
}
let montage=makeContext(1920,960)
for (i,img) in natives.enumerated(){montage.draw(img,in:CGRect(x:(i%3)*640,y:(1-i/3)*480,width:640,height:480))}
try png(montage.makeImage()!,previews.appendingPathComponent("UI-montage.png"))
let report:[String:Any]=["renderer":"Swift AppKit / CoreGraphics", "font":fontUsed,"font_family":"Noto Sans SC","variation_weights":[400,600,700],"native_size":[640,480],"preview_scale":2,"text_metrics":metrics]
try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:assetRoot.appendingPathComponent("text_audit.json"))
let failures=metrics.filter {
    ($0["missing_glyph_count"] as! Int)>0 ||
    !($0["inside_canvas"] as! Bool) ||
    !($0["core_text_safe"] as! Bool) ||
    !($0["ink_inside_24px_safe_frame"] as! Bool)
}
if !failures.isEmpty {
    for m in failures {
        FileHandle.standardError.write(Data(("TEXT_AUDIT_FAILED: \(m)\n").utf8))
    }
    fail("\(failures.count) text spans failed glyph, canvas or safety-frame checks; see assets/design/text_audit.json")
}
print("Rendered six native PNG/PPM and 2x previews + montage; font: \(fontUsed); text audit PASS (\(metrics.count) spans)")
