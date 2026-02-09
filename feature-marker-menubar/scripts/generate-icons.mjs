import { Resvg } from '@resvg/resvg-js';
import { readFileSync, writeFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const iconsDir = join(__dirname, '..', 'src-tauri', 'icons');

function convertSvgToPng(svgPath, pngPath, width, height) {
  const svg = readFileSync(svgPath, 'utf8');
  const resvg = new Resvg(svg, {
    fitTo: { mode: 'width', value: width },
  });
  const pngData = resvg.render();
  const pngBuffer = pngData.asPng();
  writeFileSync(pngPath, pngBuffer);
  console.log(`Generated: ${pngPath}`);
}

// Main app icon
convertSvgToPng(
  join(iconsDir, 'icon.svg'),
  join(iconsDir, 'icon.png'),
  512, 512
);

convertSvgToPng(
  join(iconsDir, 'icon.svg'),
  join(iconsDir, '128x128.png'),
  128, 128
);

convertSvgToPng(
  join(iconsDir, 'icon.svg'),
  join(iconsDir, '128x128@2x.png'),
  256, 256
);

convertSvgToPng(
  join(iconsDir, 'icon.svg'),
  join(iconsDir, '32x32.png'),
  32, 32
);

// Tray icon (template for menu bar)
convertSvgToPng(
  join(iconsDir, 'tray-icon.svg'),
  join(iconsDir, 'tray-icon.png'),
  22, 22
);

convertSvgToPng(
  join(iconsDir, 'tray-icon.svg'),
  join(iconsDir, 'tray-icon@2x.png'),
  44, 44
);

console.log('All icons generated successfully!');
