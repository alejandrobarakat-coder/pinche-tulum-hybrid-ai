import 'package:webview_flutter/webview_flutter.dart';

Future<void> fitMobileWebPage(WebViewController controller) =>
    controller.runJavaScript(r'''
(() => {
  let viewport = document.querySelector('meta[name="viewport"]');
  if (!viewport) {
    viewport = document.createElement('meta');
    viewport.name = 'viewport';
    document.head.appendChild(viewport);
  }
  viewport.content = 'width=device-width, initial-scale=1';

  if (!document.getElementById('pinche-mobile-layout')) {
    const style = document.createElement('style');
    style.id = 'pinche-mobile-layout';
    style.textContent = `
      html, body { max-width: 100% !important; }
      body { overflow-wrap: anywhere; }
      img, video, iframe, svg { max-width: 100% !important; }
      img, video { height: auto !important; }
      pre { max-width: 100%; overflow-x: auto; }
      .pinche-table-scroll { max-width: 100%; overflow-x: auto; }
    `;
    document.head.appendChild(style);
  }

  for (const table of document.querySelectorAll('table')) {
    if (table.parentElement.classList.contains('pinche-table-scroll')) continue;
    const wrapper = document.createElement('div');
    wrapper.className = 'pinche-table-scroll';
    table.before(wrapper);
    wrapper.appendChild(table);
  }
})();
''');
