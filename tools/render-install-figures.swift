// Renders the install guide's step pictures (docs/install/step*.png) from the website's install section,
// so the pictures and the site always show the same thing. Run from the repo root after changing
// site/index.html (for example the version on the release page):
//
//   swift tools/render-install-figures.swift
//
// Uses WebKit offscreen; nothing is opened on screen. Pictures are 849 pixels wide, like before.
import AppKit
import WebKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let site = root.appendingPathComponent("site/index.html")
let outDir = root.appendingPathComponent("docs/install", isDirectory: true)
/// Step number on the site → picture used by docs/INSTALL.md. Step 3 has no picture in the guide.
let names = ["1": "step1-download", "2": "step2-drag", "4": "step4-menu-bar", "5": "step5-widgets", "6": "step6-token"]
let figureWidth: CGFloat = 424.5
let pixelWidth = 849

struct Figure: Decodable { let n: String; let x: CGFloat; let y: CGFloat; let w: CGFloat; let h: CGFloat }

@MainActor
final class Renderer: NSObject, WKNavigationDelegate {
    let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 1100, height: 6000))
    let window = NSWindow(contentRect: NSRect(x: -20000, y: 0, width: 1100, height: 6000),
                          styleMask: [.borderless], backing: .buffered, defer: false)

    func start() {
        web.appearance = NSAppearance(named: .aqua)
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = web
        web.navigationDelegate = self
        web.loadFileURL(site, allowingReadAccessTo: site.deletingLastPathComponent())
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in await self.render() }
    }

    func render() async {
        do {
            // Show only the install guide, one step per row, figures at the size the pictures use.
            _ = try await web.evaluateJavaScript("""
                document.querySelectorAll('.view').forEach(function(v){ v.hidden = (v.id !== 'view-install'); });
                var st = document.createElement('style');
                st.textContent = '#view-install .step{display:block !important} #view-install figure{width:\(figureWidth)px !important; margin:0 !important} body{background:#fff !important}';
                document.head.appendChild(st); window.scrollTo(0, 0); true;
                """)
            try await Task.sleep(for: .seconds(1.5)) // web fonts and layout
            let json = try await web.evaluateJavaScript("""
                JSON.stringify(Array.prototype.slice.call(document.querySelectorAll('#view-install .step')).map(function(step){
                  var num = step.querySelector('.num'), fig = step.querySelector('figure');
                  if (!num || !fig) return null;
                  var r = fig.getBoundingClientRect();
                  return {n: num.textContent.trim(), x: r.left, y: r.top, w: r.width, h: r.height};
                }).filter(Boolean));
                """) as? String ?? "[]"
            let figures = try JSONDecoder().decode([Figure].self, from: Data(json.utf8))
            var written = 0
            for f in figures {
                guard let name = names[f.n] else { continue }
                let config = WKSnapshotConfiguration()
                // Leave a little room so the rounded border isn't clipped.
                config.rect = CGRect(x: f.x - 6, y: f.y - 6, width: f.w + 12, height: f.h + 12)
                config.snapshotWidth = NSNumber(value: Double(pixelWidth) / Double(window.backingScaleFactor))
                let image = try await web.takeSnapshot(configuration: config)
                guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
                let rep = NSBitmapImageRep(cgImage: cg)
                guard let png = rep.representation(using: .png, properties: [:]) else { continue }
                try png.write(to: outDir.appendingPathComponent("\(name).png"))
                print("Wrote docs/install/\(name).png (\(cg.width)×\(cg.height))")
                written += 1
            }
            guard written == names.count else {
                fputs("Expected \(names.count) pictures, wrote \(written). Did the site's install section change?\n", stderr)
                exit(1)
            }
            exit(0)
        } catch {
            fputs("Rendering failed: \(error)\n", stderr)
            exit(1)
        }
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    let renderer = Renderer()
    renderer.start()
    // Give up after a minute rather than hang (lesson: every background job gets a time limit).
    DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
        fputs("Timed out after 60 s\n", stderr)
        exit(2)
    }
    withExtendedLifetime(renderer) { app.run() }
}
