// Renders public/icons/icon.svg to the PNG sizes iOS and the web manifest
// want. iOS ignores SVG touch icons, hence the PNGs. Re-run after editing the
// SVG:  node scripts/gen-icons.mjs
import sharp from "sharp";

const src = "public/icons/icon.svg";
const sizes = { "apple-touch-icon.png": 180, "icon-192.png": 192, "icon-512.png": 512 };

for (const [name, size] of Object.entries(sizes)) {
  await sharp(src).resize(size, size).png().toFile(`public/icons/${name}`);
  console.log(`public/icons/${name}`);
}
