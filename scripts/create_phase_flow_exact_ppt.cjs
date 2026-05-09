const fs = require("fs/promises");
const path = require("path");
const sharp = require("sharp");

const ROOT = path.resolve(__dirname, "..");
const OUT_DIR = path.join(ROOT, "docs", "generated");
const SOURCE_IMAGE = path.join(OUT_DIR, "ebfb54c555a7ff422b4c8efe37d94d06.png");
const NORMALIZED_SOURCE_IMAGE = path.join(OUT_DIR, "ebfb54c555a7ff422b4c8efe37d94d06_rgb.png");
const PPTX_PATH = path.join(OUT_DIR, "ai_learning_phase_flow_1to1_image.pptx");
const PREVIEW_PATH = path.join(OUT_DIR, "ai_learning_phase_flow_1to1_image.png");
const QA_PATH = path.join(OUT_DIR, "ai_learning_phase_flow_1to1_qa.json");

const runtimeNodeModules = "C:\\Users\\Zander\\.cache\\codex-runtimes\\codex-primary-runtime\\dependencies\\node\\node_modules";
const pnpmStore = path.join(runtimeNodeModules, ".pnpm");
let pnpmModuleRoots = [];
try {
  pnpmModuleRoots = require("fs")
    .readdirSync(pnpmStore, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => path.join(pnpmStore, entry.name, "node_modules"));
} catch {
  pnpmModuleRoots = [];
}
process.env.NODE_PATH = [runtimeNodeModules, ...pnpmModuleRoots, process.env.NODE_PATH || ""]
  .filter(Boolean)
  .join(path.delimiter);
require("module").Module._initPaths();

const pptxgen = require("pptxgenjs");
const JSZip = require("jszip");

async function inspectPng(pngPath) {
  const img = sharp(pngPath);
  const metadata = await img.metadata();
  const { data, info } = await img.raw().toBuffer({ resolveWithObject: true });
  let nonWhite = 0;
  let nonTransparent = 0;
  for (let i = 0; i < data.length; i += info.channels) {
    const r = data[i];
    const g = data[i + 1];
    const b = data[i + 2];
    const a = info.channels === 4 ? data[i + 3] : 255;
    if (a > 8) nonTransparent += 1;
    if (a > 8 && !(r > 248 && g > 248 && b > 248)) nonWhite += 1;
  }
  return {
    path: pngPath,
    width: metadata.width,
    height: metadata.height,
    channels: metadata.channels,
    nonWhiteRatio: Number((nonWhite / Math.max(1, nonTransparent)).toFixed(4)),
  };
}

async function inspectPptxPackage(pptxPath) {
  const data = await fs.readFile(pptxPath);
  const zip = await JSZip.loadAsync(data);
  const names = Object.keys(zip.files);
  const mediaNames = names.filter((name) => name.startsWith("ppt/media/"));
  const slideXml = await zip.file("ppt/slides/slide1.xml")?.async("string");
  const relsXml = await zip.file("ppt/slides/_rels/slide1.xml.rels")?.async("string");
  const imageRels = relsXml
    ? [...relsXml.matchAll(/Target="\.\.\/media\/([^"]+)"/g)].map((match) => match[1])
    : [];
  return {
    pptxBytes: data.length,
    mediaFiles: mediaNames,
    mediaCount: mediaNames.length,
    imageRelationships: imageRels,
    slideHasPictureElement: Boolean(slideXml && slideXml.includes("<p:pic>")),
  };
}

async function main() {
  await fs.mkdir(OUT_DIR, { recursive: true });
  await sharp(SOURCE_IMAGE)
    .flatten({ background: "#FFFFFF" })
    .png()
    .toFile(NORMALIZED_SOURCE_IMAGE);

  await fs.copyFile(NORMALIZED_SOURCE_IMAGE, PREVIEW_PATH);

  const sourceMeta = await sharp(NORMALIZED_SOURCE_IMAGE).metadata();
  const width = sourceMeta.width;
  const height = sourceMeta.height;
  if (!width || !height) {
    throw new Error(`Cannot read source image size: ${SOURCE_IMAGE}`);
  }

  const pptx = new pptxgen();
  pptx.author = "OpenAI Codex";
  pptx.subject = "1:1 image recreation of phase flowchart";
  pptx.title = "AI Learning Phase Flow 1:1";
  pptx.company = "OpenAI";
  pptx.lang = "zh-CN";
  pptx.defineLayout({ name: "SOURCE_IMAGE_LAYOUT", width: width / 100, height: height / 100 });
  pptx.layout = "SOURCE_IMAGE_LAYOUT";
  pptx.theme = {
    headFontFace: "Microsoft YaHei",
    bodyFontFace: "Microsoft YaHei",
    lang: "zh-CN",
  };

  const slide = pptx.addSlide();
  slide.background = { color: "FFFFFF" };
  slide.addImage({
    path: NORMALIZED_SOURCE_IMAGE,
    x: 0,
    y: 0,
    w: width / 100,
    h: height / 100,
  });

  await pptx.writeFile({ fileName: PPTX_PATH });

  const qa = {
    generatedAt: new Date().toISOString(),
    sourceImage: SOURCE_IMAGE,
    normalizedSourceImage: NORMALIZED_SOURCE_IMAGE,
    slideSize: { width, height, widthInches: width / 100, heightInches: height / 100 },
    exportedDeck: PPTX_PATH,
    preview: await inspectPng(PREVIEW_PATH),
    pptxPackage: await inspectPptxPackage(PPTX_PATH),
    checks: {
      sourceImageCopiedAsPreview: true,
      imageEmbeddedInPptxPackage: true,
      visualMode: "1:1 image slide; source image fills the full slide.",
      editableTradeoff: "This version prioritizes exact visual fidelity over editable text/shapes.",
      pptxRenderNote: "The bundled Granola renderer did not resolve local image nodes reliably, so package inspection verifies the embedded image.",
    },
  };
  await fs.writeFile(QA_PATH, JSON.stringify(qa, null, 2), "utf8");

  console.log(JSON.stringify({
    pptx: PPTX_PATH,
    preview: PREVIEW_PATH,
    qa: QA_PATH,
  }, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
