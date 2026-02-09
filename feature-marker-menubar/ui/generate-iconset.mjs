import { Resvg } from '@resvg/resvg-js';
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const iconsDir = join(__dirname, '..', 'src-tauri', 'icons');
const iconsetDir = join(iconsDir, 'icon.iconset');

// Create iconset directory
if (!existsSync(iconsetDir)) {
  mkdirSync(iconsetDir);
}

const svg = readFileSync(join(iconsDir, 'icon.svg'), 'utf8');

const sizes = [16, 32, 64, 128, 256, 512];
sizes.forEach(size => {
  const resvg = new Resvg(svg, { fitTo: { mode: 'width', value: size } });
  writeFileSync(join(iconsetDir, `icon_${size}x${size}.png`), resvg.render().asPng());
  console.log(`Generated: icon_${size}x${size}.png`);

  // @2x versions
  const size2x = size * 2;
  if (size2x <= 1024) {
    const resvg2x = new Resvg(svg, { fitTo: { mode: 'width', value: size2x } });
    writeFileSync(join(iconsetDir, `icon_${size}x${size}@2x.png`), resvg2x.render().asPng());
    console.log(`Generated: icon_${size}x${size}@2x.png`);
  }
});

console.log('iconset generated! Now run: iconutil -c icns icon.iconset');
