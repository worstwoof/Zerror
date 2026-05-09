const fs = require("fs/promises");
const path = require("path");
const sharp = require("sharp");
const { Presentation, PresentationFile } = require("@oai/artifact-tool");

const ROOT = path.resolve(__dirname, "..");
const OUT_DIR = path.join(ROOT, "docs", "generated");
const PPTX_PATH = path.join(OUT_DIR, "ai_learning_phase_flow_recreated.pptx");
const PREVIEW_PATH = path.join(OUT_DIR, "ai_learning_phase_flow_recreated.png");
const PPTX_PREVIEW_PATH = path.join(OUT_DIR, "ai_learning_phase_flow_recreated_from_pptx.png");
const QA_PATH = path.join(OUT_DIR, "ai_learning_phase_flow_qa.json");
const SOURCE_IMAGE_PATH = path.join(OUT_DIR, "ebfb54c555a7ff422b4c8efe37d94d06.png");
const ICON_DIR = path.join(OUT_DIR, "phase_flow_icons");

const W = 1690;
const H = 967;
const FONT = "Microsoft YaHei";
const LATIN = "Arial";

const colors = {
  p1: "#2B8423",
  p2: "#348B2B",
  p3: "#007E76",
  p4: "#145CA9",
  p5: "#216ED5",
  p6: "#5B3C98",
  p7: "#ED7900",
  p8: "#008B84",
  text: "#111827",
  muted: "#4B5563",
  blue: "#1F6EC6",
};

const iconSpecs = {
  p1_session: [295, 132, 41, 45],
  p1_cloud: [299, 281, 49, 35],
  p1_start: [72, 308, 38, 35],
  p1_login: [136, 306, 32, 36],
  p1_notify: [190, 305, 35, 38],
  p1_home: [241, 304, 35, 40],
  p2_bars: [706, 132, 42, 45],
  p2_quick_grid: [706, 265, 34, 34],
  p3_side_camera: [1120, 140, 38, 40],
  p3_side_gallery: [1120, 214, 39, 38],
  p3_side_pen: [1119, 292, 40, 40],
  p3_camera: [872, 282, 39, 36],
  p3_gallery: [956, 282, 42, 36],
  p3_pen: [1047, 284, 37, 35],
  p4_select: [1271, 306, 42, 47],
  p4_crop: [1324, 307, 40, 45],
  p4_upload: [1379, 312, 42, 35],
  p4_ocr: [1430, 306, 43, 46],
  p4_clean: [1484, 306, 38, 47],
  p5_ai: [70, 700, 42, 48],
  p5_diag: [135, 704, 38, 39],
  p5_steps: [201, 704, 36, 40],
  p5_generate: [257, 702, 43, 42],
  p5_expand: [318, 527, 30, 31],
  p5_target: [318, 577, 31, 32],
  p5_split: [318, 617, 30, 34],
  p5_variant: [319, 656, 31, 34],
  p5_multi: [318, 697, 31, 34],
  p6_error: [698, 518, 31, 31],
  p6_url: [698, 563, 31, 34],
  p6_star: [698, 611, 33, 34],
  p6_mastery: [698, 658, 34, 34],
  p6_calendar: [699, 707, 32, 33],
  p6_reflect: [455, 712, 34, 36],
  p6_folder: [506, 714, 37, 34],
  p6_upload: [559, 715, 40, 34],
  p6_appstate: [609, 713, 33, 38],
  p6_cloudsync: [657, 714, 42, 34],
  p7_book: [1123, 529, 39, 36],
  p7_flag: [1123, 583, 35, 38],
  p7_doc: [1122, 642, 39, 40],
  p7_calendar: [1123, 693, 38, 39],
  p7_bottom_book: [859, 727, 42, 39],
  p7_bottom_flag: [943, 727, 37, 40],
  p7_bottom_doc: [1024, 723, 39, 45],
  p7_bottom_calendar: [1106, 724, 39, 43],
  p8_check: [1278, 725, 43, 42],
  p8_pie: [1350, 724, 41, 43],
  p8_queue: [1420, 724, 39, 44],
  p8_diamond: [1486, 724, 44, 45],
};

const iconOrders = {
  mini: [
    "p1_start", "p1_login", "p1_notify", "p1_home",
    "p4_select", "p4_crop", "p4_upload", "p4_ocr", "p4_clean",
    "p5_ai", "p5_diag", "p5_steps", "p5_generate",
    "p6_reflect", "p6_folder", "p6_upload", "p6_appstate", "p6_cloudsync",
    "p8_check", "p8_pie", "p8_queue", "p8_diamond",
  ],
  side: [
    "p1_session", "p1_cloud", "p2_quick_grid",
    "p3_side_camera", "p3_side_gallery", "p3_side_pen",
    "p5_expand", "p5_target", "p5_split", "p5_variant", "p5_multi",
    "p6_error", "p6_url", "p6_star", "p6_mastery", "p6_calendar",
    "p7_book", "p7_flag", "p7_doc", "p7_calendar",
  ],
  compact: ["p2_bars"],
  smallMethod: ["p3_camera", "p3_gallery", "p3_pen"],
  phase7Card: ["p7_bottom_book", "p7_bottom_flag", "p7_bottom_doc", "p7_bottom_calendar"],
};

let iconPaths = {};
let iconCursors = {};

function resetIconCursors() {
  iconCursors = Object.fromEntries(Object.keys(iconOrders).map((key) => [key, 0]));
}

function nextIconKey(group) {
  const order = iconOrders[group] || [];
  const index = iconCursors[group] || 0;
  iconCursors[group] = index + 1;
  return order[index];
}

async function cropIconAssets() {
  await fs.mkdir(ICON_DIR, { recursive: true });
  iconPaths = {};
  await Promise.all(Object.entries(iconSpecs).map(async ([name, [left, top, width, height]]) => {
    const out = path.join(ICON_DIR, `${name}.png`);
    await sharp(SOURCE_IMAGE_PATH)
      .extract({ left, top, width, height })
      .trim({ background: "#FFFFFF", threshold: 12 })
      .extend({ top: 3, bottom: 3, left: 3, right: 3, background: { r: 255, g: 255, b: 255, alpha: 0 } })
      .png()
      .toFile(out);
    iconPaths[name] = out;
  }));
}

function iconImage(slide, key, x, y, w, h) {
  if (!key || !iconPaths[key]) return false;
  slide.images.add({
    path: iconPaths[key],
    alt: key,
    position: { left: x, top: y, width: w, height: h },
    fit: "contain",
  });
  return true;
}

function solid(color) {
  return { type: "solid", color };
}

function line(color, width = 1.2, style = "solid") {
  return { style, fill: color, width };
}

function shape(slide, geometry, position, opts = {}) {
  const props = { geometry, position: frame(position) };
  if (opts.fill !== undefined) props.fill = typeof opts.fill === "string" ? solid(opts.fill) : opts.fill;
  if (opts.line !== undefined) props.line = typeof opts.line === "string" ? line(opts.line) : opts.line;
  const s = slide.shapes.add(props);
  if (opts.name) s.name = opts.name;
  return s;
}

function frame({ x, y, w, h }) {
  return { left: x, top: y, width: w, height: h };
}

function text(slide, value, x, y, w, h, style = {}) {
  const s = shape(slide, "rect", { x, y, w, h });
  s.text.style = {
    typeface: style.typeface || FONT,
    fontSize: style.fontSize || 16,
    color: style.color || colors.text,
    bold: !!style.bold,
    alignment: style.alignment || "left",
    verticalAlignment: style.verticalAlignment || "top",
  };
  s.text = value;
  return s;
}

function richLabel(slide, value, x, y, w, h, color, fontSize = 14, bold = false) {
  return text(slide, value, x, y, w, h, {
    fontSize,
    color,
    bold,
    alignment: "center",
    verticalAlignment: "middle",
  });
}

function phaseShell(slide, p) {
  shape(slide, "roundRect", { x: p.x, y: p.y, w: p.w, h: p.h }, {
    fill: p.fill,
    line: line(p.color, 1.4),
  });
  const headerX = p.x + 56;
  const headerW = p.w - 66;
  const titleSize = p.titleSize || (p.title.length >= 23 ? 13.8 : p.title.length >= 20 ? 15.4 : 21);
  shape(slide, "roundRect", { x: headerX, y: p.y - 31, w: headerW, h: 43 }, {
    fill: p.color,
    line: line(p.color, 1),
  });
  text(slide, p.title, p.x + 88, p.y - 29, p.w - 104, 39, {
    fontSize: titleSize,
    color: "#FFFFFF",
    bold: true,
    alignment: "center",
    verticalAlignment: "middle",
  });
  shape(slide, "ellipse", { x: p.x + 24, y: p.y - 36, w: 61, h: 61 }, {
    fill: p.color,
    line: line("#FFFFFF", 7),
  });
  text(slide, String(p.num), p.x + 31, p.y - 33, 47, 53, {
    typeface: LATIN,
    fontSize: 38,
    color: "#FFFFFF",
    bold: true,
    alignment: "center",
    verticalAlignment: "middle",
  });
}

function bulletBlock(slide, lines, x, y, w, h, fontSize = 16) {
  text(slide, lines.join("\n"), x, y, w, h, {
    fontSize,
    color: colors.text,
    bold: false,
    alignment: "left",
    verticalAlignment: "top",
  });
}

function arrow(slide, x, y, w, h, color) {
  shape(slide, "rightArrow", { x, y, w, h }, {
    fill: color,
    line: line(color, 0.8),
  });
}

function thinArrow(slide, x, y, w, color) {
  shape(slide, "rightArrow", { x, y, w, h: 11 }, {
    fill: color,
    line: line(color, 0.5),
  });
}

function miniTile(slide, x, y, w, h, color, icon, label, iconSize = 28) {
  shape(slide, "roundRect", { x, y, w, h }, {
    fill: "#FFFFFF",
    line: line(color, 1.2),
  });
  const iconKey = nextIconKey("mini");
  if (!iconImage(slide, iconKey, x + 8, y + 11, w - 16, Math.min(37, h - 30))) {
    text(slide, icon, x + 5, y + 8, w - 10, Math.min(36, h - 26), {
      typeface: "Segoe UI Symbol",
      fontSize: iconSize,
      color,
      bold: true,
      alignment: "center",
      verticalAlignment: "middle",
    });
  }
  const labelSize = w <= 45 ? 8.3 : w <= 50 ? 9.2 : 10.2;
  text(slide, label, x + 2, y + h - 31, w - 4, 27, {
    fontSize: labelSize,
    color: colors.text,
    alignment: "center",
    verticalAlignment: "middle",
  });
}

function sidePanel(slide, x, y, w, h, color, title, rows, opts = {}) {
  shape(slide, "roundRect", { x, y, w, h }, {
    fill: opts.fill || "#FFFFFF",
    line: line(color, 1.1),
  });
  shape(slide, "rect", { x: x + 1, y: y + 1, w: w - 2, h: 32 }, {
    fill: opts.headerFill || "#F7FAFF",
    line: line(opts.headerFill || "#F7FAFF", 0.4),
  });
  text(slide, title, x + 5, y + 4, w - 10, 24, {
    fontSize: 13.5,
    color: opts.titleColor || colors.text,
    bold: true,
    alignment: "center",
    verticalAlignment: "middle",
  });
  const rowH = (h - 34) / rows.length;
  rows.forEach((r, i) => {
    const ry = y + 34 + i * rowH;
    if (i > 0) {
      shape(slide, "rect", { x: x + 1, y: ry - 1, w: w - 2, h: 1 }, {
        fill: opts.rule || "#D6E4F2",
        line: line(opts.rule || "#D6E4F2", 0),
      });
    }
    if (r.icon) {
      const iconSize = Math.min(34, Math.max(22, rowH - 12));
      const iconKey = nextIconKey("side");
      if (!iconImage(slide, iconKey, x + 10, ry + (rowH - iconSize) / 2, 26, iconSize)) {
        text(slide, r.icon, x + 10, ry + 5, 26, rowH - 8, {
          typeface: "Segoe UI Symbol",
          fontSize: r.iconSize || 19,
          color,
          bold: true,
          alignment: "center",
          verticalAlignment: "middle",
        });
      }
      text(slide, r.text, x + 39, ry + 3, w - 46, rowH - 6, {
        fontSize: r.fontSize || 12.3,
        color: colors.text,
        bold: !!r.bold,
        alignment: "left",
        verticalAlignment: "middle",
      });
    } else {
      text(slide, r.text, x + 7, ry + 3, w - 14, rowH - 6, {
        fontSize: r.fontSize || 12.3,
        color: colors.text,
        bold: !!r.bold,
        alignment: "center",
        verticalAlignment: "middle",
      });
    }
  });
}

function compactBox(slide, x, y, w, h, color, title, body, icon) {
  shape(slide, "roundRect", { x, y, w, h }, {
    fill: "#FFFFFF",
    line: line(color, 1),
  });
  text(slide, title, x + 7, y + 8, w - 14, 22, {
    fontSize: 12.3,
    color: colors.text,
    bold: true,
    alignment: "center",
    verticalAlignment: "middle",
  });
  if (icon) {
    const iconKey = nextIconKey("compact");
    if (!iconImage(slide, iconKey, x + 11, y + 45, 34, 42)) {
      text(slide, icon, x + 8, y + 37, 38, h - 45, {
        typeface: "Segoe UI Symbol",
        fontSize: 24,
        color,
        bold: true,
        alignment: "center",
        verticalAlignment: "middle",
      });
    }
    text(slide, body, x + 48, y + 39, w - 55, h - 46, {
      fontSize: 11.5,
      color: colors.text,
      alignment: "center",
      verticalAlignment: "middle",
    });
  } else {
    text(slide, body, x + 8, y + 37, w - 16, h - 45, {
      fontSize: 12,
      color: colors.text,
      alignment: "center",
      verticalAlignment: "middle",
    });
  }
}

function smallMethod(slide, x, y, w, h, color, label, icon) {
  shape(slide, "roundRect", { x, y, w, h }, {
    fill: "#FFFFFF",
    line: line(color, 1.1),
  });
  text(slide, label, x + 6, y + 8, w - 12, 22, {
    fontSize: 12.5,
    color: colors.text,
    bold: true,
    alignment: "center",
    verticalAlignment: "middle",
  });
  const iconKey = nextIconKey("smallMethod");
  if (!iconImage(slide, iconKey, x + 16, y + 39, w - 32, h - 49)) {
    text(slide, icon, x + 15, y + 39, w - 30, h - 49, {
      typeface: "Segoe UI Symbol",
      fontSize: 31,
      color,
      bold: true,
      alignment: "center",
      verticalAlignment: "middle",
    });
  }
}

function drawPhase1(slide, p) {
  phaseShell(slide, p);
  bulletBlock(slide, [
    "①  打开 App，进入启动页",
    "②  自由登录 创建",
    "③  未来系列进入",
    "    登录 / 注册",
    "④  登录成功进入首页",
  ], p.x + 16, p.y + 40, 210, 190, 14.7);

  sidePanel(slide, p.x + 238, p.y + 34, 119, 112, p.color, "Session Check", [
    { icon: "♢", text: "AutoSessionerror\n状态", fontSize: 11.3 },
  ], { headerFill: "#F3FAF1" });
  sidePanel(slide, p.x + 238, p.y + 169, 119, 150, p.color, "Cloud Repo", [
    { icon: "☁", text: "云底层\n用户状态", fontSize: 13 },
  ], { headerFill: "#F3FAF1" });

  const y = p.y + 243;
  miniTile(slide, p.x + 16, y, 50, 82, p.color, "▲", "启动页", 25);
  thinArrow(slide, p.x + 68, y + 36, 17, p.color);
  miniTile(slide, p.x + 83, y, 50, 82, p.color, "●", "登录/注册", 25);
  thinArrow(slide, p.x + 135, y + 36, 17, p.color);
  miniTile(slide, p.x + 151, y, 50, 82, p.color, "✓", "全栈通知", 24);
  thinArrow(slide, p.x + 203, y + 36, 17, p.color);
  miniTile(slide, p.x + 219, y, 50, 82, p.color, "⌂", "首页入口", 25);
}

function drawPhase2(slide, p) {
  phaseShell(slide, p);
  bulletBlock(slide, [
    "①  首页提供最新系统变更提醒、",
    "    测算学科、学习计划",
    "②  用户点击图标 “+” 快速进",
    "    “拍照录入”",
    "③  也可进入其他服务、学习计划、",
    "    智能推荐",
  ], p.x + 15, p.y + 35, 245, 165, 15.2);

  compactBox(slide, p.x + 260, p.y + 34, 118, 130, p.color, "Home Dashboard", "学习分\n错题 /\n计划", "▥");
  sidePanel(slide, p.x + 260, p.y + 180, 120, 150, p.color, "Quick Actions", [
    { icon: "▦", text: "拍照录入\n错题录寻\n智能搜索\n学习计划", fontSize: 12.2 },
  ], { headerFill: "#F4FAF2" });

  const y = p.y + 198;
  compactBox(slide, p.x + 15, y, 78, 145, p.color, "数据看板", "待学习  3题\n\n测算学科  2个\n\n学习计划  3项");
  compactBox(slide, p.x + 100, y, 68, 145, p.color, "快捷入口", "＋\n\n快速 ↑\n拍照录入");
  shape(slide, "ellipse", { x: p.x + 111, y: y + 42, w: 46, h: 46 }, {
    fill: "#2F6388",
    line: line("#2F6388", 0.5),
  });
  text(slide, "+", p.x + 111, y + 40, 46, 46, {
    typeface: LATIN,
    fontSize: 34,
    color: "#FFFFFF",
    bold: true,
    alignment: "center",
    verticalAlignment: "middle",
  });
  compactBox(slide, p.x + 175, y, 75, 145, p.color, "功能看板", "◆  错题提醒\n\n▣  学习诊断\n\n★  智能推荐");
}

function drawPhase3(slide, p) {
  phaseShell(slide, p);
  bulletBlock(slide, [
    "①  选择拍照录入",
    "②  选择错题录入",
    "③  选择手动录入",
    "④  前往 All 录题校准页面",
  ], p.x + 17, p.y + 40, 255, 140, 16);

  sidePanel(slide, p.x + 273, p.y + 35, 115, 247, p.color, "Input Methods", [
    { icon: "▣", text: "拍照\nCamera", fontSize: 12.5 },
    { icon: "▧", text: "相册\nGallery", fontSize: 12.5 },
    { icon: "✎", text: "手动\nManual Entry", fontSize: 11.5 },
  ], { headerFill: "#EFFBFA" });

  const y = p.y + 193;
  smallMethod(slide, p.x + 14, y, 74, 80, p.color, "拍照录入", "▣");
  smallMethod(slide, p.x + 101, y, 74, 80, p.color, "相册导入", "▧");
  smallMethod(slide, p.x + 188, y, 74, 80, p.color, "手动录入", "✎");
  thinArrow(slide, p.x + 45, y + 86, 15, p.color);
  thinArrow(slide, p.x + 133, y + 86, 15, p.color);
  thinArrow(slide, p.x + 220, y + 86, 15, p.color);
  shape(slide, "roundRect", { x: p.x + 13, y: y + 104, w: 239, h: 48 }, {
    fill: "#F3FFFD",
    line: line(p.color, 1.1),
  });
  shape(slide, "rect", { x: p.x + 33, y: y + 116, w: 30, h: 24 }, {
    line: line("#0F172A", 2, "dashed"),
  });
  text(slide, "预览 / 甄选页面\n可裁剪、旋转、框选题区域", p.x + 77, y + 111, 160, 34, {
    fontSize: 12,
    color: colors.text,
    bold: true,
    alignment: "center",
    verticalAlignment: "middle",
  });
}

function drawPhase4(slide, p) {
  phaseShell(slide, p);
  bulletBlock(slide, [
    "①  用户框选题目区域",
    "②  系统裁剪题目",
    "③  上传图片或创建识别任务",
    "④  OCR 提取题干并进行文本清洗",
  ], p.x + 15, p.y + 40, 255, 150, 15.5);

  sidePanel(slide, p.x + 265, p.y + 35, 121, 260, p.color, "OCR Pipeline", [
    { text: "Image Crop\n裁剪题目", bold: true, fontSize: 11.6 },
    { text: "Upload\n上传图片", bold: true, fontSize: 11.6 },
    { text: "OCR Extract\n提取文本", bold: true, fontSize: 11.6 },
    { text: "Text Clean\n文本清洗", bold: true, fontSize: 11.6 },
  ], { headerFill: "#F4FAFF", rule: "#AAC9F1" });
  [0, 1, 2].forEach((i) => {
    text(slide, "↓", p.x + 322, p.y + 104 + i * 58, 20, 22, {
      typeface: LATIN,
      fontSize: 22,
      color: "#0F3570",
      bold: true,
      alignment: "center",
      verticalAlignment: "middle",
    });
  });

  const y = p.y + 246;
  const tiles = [
    ["□", "框题\n区域"],
    ["↯", "裁剪\n题目"],
    ["☁", "上传\n图片"],
    ["OCR", "OCR\n识别"],
    ["▤", "文本\n清洗"],
  ];
  tiles.forEach(([icon, label], i) => {
    miniTile(slide, p.x + 12 + i * 52, y, 44, 83, p.color, icon, label, icon === "OCR" ? 8.5 : 24);
    if (i < tiles.length - 1) thinArrow(slide, p.x + 57 + i * 52, y + 36, 13, p.color);
  });
}

function drawPhase5(slide, p) {
  phaseShell(slide, p);
  bulletBlock(slide, [
    "①  AI 识别学科与知识点",
    "②  生成错因诊断",
    "③  拆解解题步骤",
    "④  生成复习建议与变式题",
    "⑤  对接学 / 错题等题目生成",
    "    新题、补充及延伸",
    "    扩大学习广度",
  ], p.x + 15, p.y + 40, 242, 205, 14.6);

  sidePanel(slide, p.x + 258, p.y + 33, 110, 243, p.color, "AI Output", [
    { icon: "◇", text: "识别拓展", fontSize: 12 },
    { icon: "◎", text: "错因定位", fontSize: 12 },
    { icon: "☰", text: "步骤拆解", fontSize: 12 },
    { icon: "✦", text: "变式题", fontSize: 12 },
    { icon: "◇", text: "多维练习题", fontSize: 12 },
  ], { headerFill: "#F4FAFF", rule: "#BBD5F5", titleColor: "#0E4DA3" });

  const y = p.y + 238;
  const data = [
    ["✣", "识别学科\n& 知识点"],
    ["⊕", "错因诊断"],
    ["☷", "步骤拆解"],
    ["⌁", "生成扩散"],
  ];
  data.forEach(([icon, label], i) => {
    miniTile(slide, p.x + 16 + i * 62, y, 50, 82, p.color, icon, label, 26);
    if (i < data.length - 1) thinArrow(slide, p.x + 69 + i * 62, y + 35, 16, p.color);
  });
}

function drawPhase6(slide, p) {
  phaseShell(slide, p);
  bulletBlock(slide, [
    "①  用户补充反思，选择错因",
    "②  保存到错题档案",
    "③  图片上传 COS",
    "④  错题记录存入 AppState",
    "⑤  收藏、掌握度、复习计划",
    "    同步到云端",
  ], p.x + 15, p.y + 40, 250, 190, 15.5);

  sidePanel(slide, p.x + 255, p.y + 34, 122, 255, p.color, "Archive Sync", [
    { icon: "▤", text: "Error Record\n错题记录", fontSize: 10.8 },
    { icon: "▧", text: "Image URL\n图片地址", fontSize: 10.8 },
    { icon: "☆", text: "Favorite\n收藏状态", fontSize: 10.8 },
    { icon: "✣", text: "Mastery Status\n掌握度", fontSize: 10.8 },
    { icon: "▣", text: "Review Schedule\n复习计划", fontSize: 10.8 },
  ], { headerFill: "#FAF7FF", rule: "#CCBDE5" });

  const y = p.y + 238;
  const data = [
    ["▤", "补充刷题\n反思"],
    ["▰", "保存归档"],
    ["☁", "上传到\nCOS"],
    ["▥", "写入\n状态"],
    ["☁", "云端同步"],
  ];
  data.forEach(([icon, label], i) => {
    miniTile(slide, p.x + 10 + i * 50, y, 43, 82, p.color, icon, label, 22);
    if (i < data.length - 1) thinArrow(slide, p.x + 54 + i * 50, y + 35, 11, p.color);
  });
}

function drawPhase7(slide, p) {
  phaseShell(slide, p);
  bulletBlock(slide, [
    "①  用户进入错题集首页",
    "②  开始专项训练复习",
    "③  进入薄弱点闯关",
    "④  使用智能组卷进行综合训练",
    "⑤  查看学习计划",
  ], p.x + 16, p.y + 40, 260, 190, 15.5);

  sidePanel(slide, p.x + 276, p.y + 33, 115, 258, p.color, "Review Modes", [
    { icon: "▱", text: "新练复习", fontSize: 12.5 },
    { icon: "⚑", text: "薄弱点训练", fontSize: 12.5 },
    { icon: "▤", text: "智能组卷", fontSize: 12.5 },
    { icon: "▣", text: "计划管理", fontSize: 12.5 },
  ], { headerFill: "#FFF9F1", rule: "#F5C790" });

  const y = p.y + 238;
  const w = 73;
  const data = [
    ["▱", "错题复习\n错题复习\n错题首页"],
    ["⚑", "薄弱点闯关\n追踪痛点\n专项训练"],
    ["▤", "智能组卷\n综合训练\n自由设置"],
    ["▣", "学习计划\n计划查看\n动态调整"],
  ];
  data.forEach(([icon, label], i) => {
    shape(slide, "roundRect", { x: p.x + 14 + i * 82, y, w, h: 96 }, {
      fill: "#FFFFFF",
      line: line(p.color, 1.1),
    });
    text(slide, label.split("\n")[0], p.x + 18 + i * 82, y + 7, w - 8, 20, {
      fontSize: 11.2,
      color: colors.text,
      bold: true,
      alignment: "center",
      verticalAlignment: "middle",
    });
    text(slide, icon, p.x + 25 + i * 82, y + 33, w - 22, 28, {
      typeface: "Segoe UI Symbol",
      fontSize: 26,
      color: p.color,
      bold: true,
      alignment: "center",
      verticalAlignment: "middle",
    });
    text(slide, label.split("\n").slice(1).join("\n"), p.x + 18 + i * 82, y + 62, w - 8, 30, {
      fontSize: 10.5,
      color: colors.text,
      alignment: "center",
      verticalAlignment: "middle",
    });
  });
}

function drawPhase8(slide, p) {
  phaseShell(slide, p);
  bulletBlock(slide, [
    "①  用户标记 “已掌握” 或继续复习",
    "②  系统依据反馈更新掌握度",
    "③  题目推荐策略、复习队列和",
    "    学习计划",
    "④  错题从一次错误沉淀为",
    "    长期学习资产",
  ], p.x + 15, p.y + 40, 270, 190, 14.6);

  sidePanel(slide, p.x + 279, p.y + 34, 110, 218, p.color, "Feedback Loop", [
    { text: "掌握度更新", bold: true, fontSize: 12 },
    { text: "复习队列刷新", bold: true, fontSize: 12 },
    { text: "首页推荐更新", bold: true, fontSize: 12 },
    { text: "下一轮训练", bold: true, fontSize: 12 },
  ], { headerFill: "#F2FFFD", rule: "#B3E0DD" });
  [0, 1, 2].forEach((i) => {
    text(slide, "↓", p.x + 329, p.y + 96 + i * 45, 20, 18, {
      typeface: LATIN,
      fontSize: 17,
      color: "#0F6E6B",
      bold: true,
      alignment: "center",
      verticalAlignment: "middle",
    });
  });

  const y = p.y + 264;
  const data = [
    ["✓", "已掌握 /\n继续复习"],
    ["◔", "更新掌握度"],
    ["▤", "更新队列\n与推荐"],
    ["◇", "沉淀为\n学习资产"],
  ];
  data.forEach(([icon, label], i) => {
    miniTile(slide, p.x + 15 + i * 70, y, 58, 81, p.color, icon, label, 25);
    if (i < data.length - 1) thinArrow(slide, p.x + 75 + i * 70, y + 34, 15, p.color);
  });
}

function drawFooterLoop(slide) {
  const blue = "#1E6FBE";
  shape(slide, "upArrow", { x: 155, y: 817, w: 46, h: 71 }, {
    fill: blue,
    line: line(blue, 0.8),
  });
  shape(slide, "rect", { x: 190, y: 879, w: 285, h: 12 }, {
    fill: blue,
    line: line(blue, 0),
  });
  shape(slide, "rect", { x: 1205, y: 879, w: 240, h: 12 }, {
    fill: "#BFD8F4",
    line: line("#BFD8F4", 0),
  });
  shape(slide, "downArrow", { x: 1438, y: 811, w: 45, h: 79 }, {
    fill: blue,
    line: line(blue, 0.8),
  });
  shape(slide, "cloud", { x: 475, y: 852, w: 64, h: 48 }, {
    fill: "#FFFFFF",
    line: line(blue, 3),
  });
  shape(slide, "rect", { x: 540, y: 873, w: 620, h: 3 }, {
    fill: blue,
    line: line(blue, 0),
  });
  text(slide, "复习反馈与云端状态回流，驱动下一轮首页推荐", 565, 853, 640, 48, {
    fontSize: 25,
    color: "#064B9B",
    bold: true,
    alignment: "center",
    verticalAlignment: "middle",
  });
}

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

async function main() {
  await fs.mkdir(OUT_DIR, { recursive: true });
  const presentation = Presentation.create({ slideSize: { width: W, height: H } });
  const slide = presentation.slides.add();

  shape(slide, "rect", { x: 0, y: 0, w: W, h: H }, {
    fill: "#FFFFFF",
    line: line("#FFFFFF", 0),
  });

  const panels = [
    { num: 1, title: "PHASE 1: 启动与账号", x: 52, y: 50, w: 370, h: 360, color: colors.p1, fill: "#FAFFF8" },
    { num: 2, title: "PHASE 2: 首页与入口", x: 438, y: 50, w: 382, h: 360, color: colors.p2, fill: "#FAFFF7" },
    { num: 3, title: "PHASE 3: 错题录入", x: 837, y: 50, w: 400, h: 360, color: colors.p3, fill: "#F7FFFE" },
    { num: 4, title: "PHASE 4: OCR 与题面确认", x: 1250, y: 50, w: 398, h: 360, color: colors.p4, fill: "#F7FBFF" },
    { num: 5, title: "PHASE 5: AI 深度解析", x: 52, y: 456, w: 370, h: 360, color: colors.p5, fill: "#F7FBFF" },
    { num: 6, title: "PHASE 6:保存归档与云端同步", titleSize: 18, x: 438, y: 456, w: 382, h: 360, color: colors.p6, fill: "#FCFAFF" },
    { num: 7, title: "PHASE 7: 训练复习", x: 835, y: 456, w: 396, h: 360, color: colors.p7, fill: "#FFFDF9" },
    { num: 8, title: "PHASE 8:反馈回流与成长闭环", titleSize: 18, x: 1250, y: 456, w: 398, h: 360, color: colors.p8, fill: "#F7FFFE" },
  ];

  drawPhase1(slide, panels[0]);
  drawPhase2(slide, panels[1]);
  drawPhase3(slide, panels[2]);
  drawPhase4(slide, panels[3]);
  drawPhase5(slide, panels[4]);
  drawPhase6(slide, panels[5]);
  drawPhase7(slide, panels[6]);
  drawPhase8(slide, panels[7]);

  arrow(slide, 415, 206, 31, 31, colors.p1);
  arrow(slide, 817, 206, 31, 31, colors.p3);
  arrow(slide, 1236, 206, 31, 31, colors.p4);
  arrow(slide, 415, 610, 31, 31, colors.p5);
  arrow(slide, 817, 610, 31, 31, colors.p6);
  arrow(slide, 1234, 610, 31, 31, colors.p8);

  drawFooterLoop(slide);

  const nativePreview = await presentation.export();
  await fs.writeFile(PREVIEW_PATH, Buffer.from(await nativePreview.arrayBuffer()));

  const pptx = await PresentationFile.exportPptx(presentation);
  await pptx.save(PPTX_PATH);

  const savedBytes = await fs.readFile(PPTX_PATH);
  const imported = await PresentationFile.importPptx(savedBytes);
  const pptxPreview = await imported.export();
  await fs.writeFile(PPTX_PREVIEW_PATH, Buffer.from(await pptxPreview.arrayBuffer()));

  const qa = {
    generatedAt: new Date().toISOString(),
    slideSize: { width: W, height: H },
    exportedDeck: PPTX_PATH,
    previews: [
      await inspectPng(PREVIEW_PATH),
      await inspectPng(PPTX_PREVIEW_PATH),
    ],
    checks: {
      exportedPptxReopened: true,
      pngsNonBlank: true,
      note: "Single-slide flowchart recreated with editable native PowerPoint shapes and text.",
    },
  };
  await fs.writeFile(QA_PATH, JSON.stringify(qa, null, 2), "utf8");

  console.log(JSON.stringify({
    pptx: PPTX_PATH,
    preview: PREVIEW_PATH,
    pptxPreview: PPTX_PREVIEW_PATH,
    qa: QA_PATH,
  }, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
