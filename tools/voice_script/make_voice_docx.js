// Charm Combo: the readable voice script (.docx), grouped by scene like a play.
//
// Usage (from the project folder), after make_voice_script.py has written
// docs/voice/voice_lines.json:
//     node tools/voice_script/make_voice_docx.js [docs/voice]
// Writes Charm_Combo_Voice_Script.docx next to the spreadsheet. Needs Node.js
// with the "docx" package (npm install docx).
const fs = require("fs");
const path = require("path");
const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, AlignmentType, Footer, Header,
  PageNumber, PageBreak, Table, TableRow, TableCell, WidthType, ShadingType, BorderStyle,
} = require("docx");

const outDir = process.argv[2] || path.join(__dirname, "..", "..", "docs", "voice");
const data = JSON.parse(fs.readFileSync(path.join(outDir, "voice_lines.json"), "utf8"));

const FONT = "Arial";
const INK = "2E2433";
const SOFT = "7A6B78";
const PLUM = "8E2F63";
const EMOTION_COLOR = {
  neutral: "6B6B6B", happy: "2F7D4A", shy: "B0457A", surprised: "B7791F",
  teasing: "7A3FB0", sad: "3C6E9E", angry: "B23A3A",
};

function p(text, opts = {}) {
  return new Paragraph({
    spacing: { before: opts.before || 0, after: opts.after === undefined ? 80 : opts.after },
    indent: opts.indent ? { left: opts.indent } : undefined,
    keepNext: opts.keepNext || false,
    children: [new TextRun({ text, font: FONT, size: opts.size || 21, bold: opts.bold, italics: opts.italics, color: opts.color || INK })],
  });
}

function intro() {
  const out = [];
  out.push(new Paragraph({ spacing: { after: 60 }, children: [new TextRun({ text: "Charm Combo", font: FONT, size: 48, bold: true, color: PLUM })] }));
  out.push(p("Voice script", { size: 32, color: SOFT, after: 240 }));
  out.push(p("An 18+ match-3 romance set in Duskhaven. This script holds every line each character speaks, in the order the player hears it, grouped by scene. The recording sheet (Charm_Combo_Voice_Script.xlsx) has the same lines, one row each, with columns to tick off takes.", { after: 160 }));
  const notes = [
    ["How to read it", "The grey italic text above a line is what has just happened in the scene (narration is never recorded). The line itself is in large type. Under it: the portrait she shows, and how to deliver it."],
    ["File names", "Save each line as its line ID plus .wav (for example amara_intro_01.wav), one line per file. The IDs match the game's files, so recordings can be hooked up later without renaming."],
    ["Audio", "WAV, 48 kHz, 24-bit, mono. About half a second of silence before and after each line. No music or effects."],
    ["Content", "Romance with sexual content. All characters are adults. Each girl has a night scene with the player; its lines in this script are intimate but not graphic. More lines for those scenes may come later as a separate session."],
    ["The player", "The player character never speaks aloud. Lines that follow 'You said' answer a choice the player picked."],
  ];
  for (const [k, v] of notes) {
    out.push(new Paragraph({
      spacing: { after: 100 },
      children: [
        new TextRun({ text: k + ". ", font: FONT, size: 21, bold: true, color: INK }),
        new TextRun({ text: v, font: FONT, size: 21, color: INK }),
      ],
    }));
  }
  // line counts
  const border = { style: BorderStyle.SINGLE, size: 4, color: "E5BCD4" };
  const borders = { top: border, bottom: border, left: border, right: border };
  const rows = [["Character", "Lines"]].concat(data.map(c => [c.name, String(c.lines.length)]));
  rows.push(["Total", String(data.reduce((a, c) => a + c.lines.length, 0))]);
  out.push(p("", { after: 60 }));
  out.push(new Table({
    width: { size: 5200, type: WidthType.DXA },
    columnWidths: [3900, 1300],
    rows: rows.map((r, i) => new TableRow({
      children: r.map((cell, j) => new TableCell({
        borders,
        width: { size: j === 0 ? 3900 : 1300, type: WidthType.DXA },
        shading: i === 0 ? { fill: "FBE6F0", type: ShadingType.CLEAR, color: "auto" } : undefined,
        margins: { top: 60, bottom: 60, left: 120, right: 120 },
        children: [new Paragraph({
          alignment: j === 1 ? AlignmentType.RIGHT : AlignmentType.LEFT,
          children: [new TextRun({ text: cell, font: FONT, size: 20, bold: i === 0 || i === rows.length - 1, color: INK })],
        })],
      })),
    })),
  }));
  return out;
}

function character(c) {
  const out = [];
  out.push(new Paragraph({ children: [new PageBreak()] }));
  out.push(new Paragraph({
    heading: HeadingLevel.HEADING_1,
    spacing: { after: 60 },
    children: [new TextRun({ text: c.name, font: FONT, size: 40, bold: true, color: c.accent.replace("#", "") })],
  }));
  out.push(p(c.role, { size: 22, color: SOFT, after: 160 }));
  out.push(p(c.voice, { after: 100 }));
  if (c.pronunciation && c.pronunciation.length) {
    out.push(new Paragraph({
      spacing: { after: 200 },
      children: [
        new TextRun({ text: "Say it: ", font: FONT, size: 20, bold: true, color: SOFT }),
        new TextRun({ text: c.pronunciation.map(([a, b]) => a + " = " + b).join("  ·  "), font: FONT, size: 20, italics: true, color: SOFT }),
      ],
    }));
  }
  let scene = null;
  let lastCtx = null;
  for (const ln of c.lines) {
    if (ln.scene !== scene) {
      scene = ln.scene;
      lastCtx = null;
      out.push(new Paragraph({
        heading: HeadingLevel.HEADING_2,
        spacing: { before: 280, after: 100 },
        keepNext: true,
        border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: "E5BCD4", space: 2 } },
        children: [new TextRun({ text: scene, font: FONT, size: 24, bold: true, color: PLUM })],
      }));
    }
    const ctx = ln.context || "";
    if (ctx && !ctx.startsWith("Her previous line") && ctx !== lastCtx) {
      lastCtx = ctx;
      out.push(p(ctx, { italics: true, color: SOFT, size: 19, indent: 360, after: 60, keepNext: true }));
    }
    out.push(new Paragraph({
      indent: { left: 360 },
      spacing: { before: 40, after: 30 },
      keepNext: true,
      children: [new TextRun({ text: ln.line, font: FONT, size: 25, color: INK })],
    }));
    out.push(new Paragraph({
      indent: { left: 360 },
      spacing: { after: 140 },
      keepLines: true,
      children: [
        new TextRun({ text: ln.id, font: "Courier New", size: 16, color: SOFT }),
        new TextRun({ text: "   " + ln.emotion, font: FONT, size: 17, bold: true, color: EMOTION_COLOR[ln.emotion] || SOFT }),
        new TextRun({ text: ln.note ? "   " + ln.note : "", font: FONT, size: 18, italics: true, color: INK }),
      ],
    }));
  }
  return out;
}

const children = intro();
for (const c of data) children.push(...character(c));

const doc = new Document({
  creator: "Charm Combo",
  title: "Charm Combo voice script",
  styles: {
    default: { document: { run: { font: FONT, size: 21 } } },
    paragraphStyles: [
      { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 40, bold: true, font: FONT }, paragraph: { spacing: { after: 60 }, outlineLevel: 0 } },
      { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 24, bold: true, font: FONT }, paragraph: { spacing: { before: 280, after: 100 }, outlineLevel: 1 } },
    ],
  },
  sections: [{
    properties: { page: { margin: { top: 1200, bottom: 1200, left: 1300, right: 1300 } } },
    headers: { default: new Header({ children: [new Paragraph({ alignment: AlignmentType.RIGHT, children: [new TextRun({ text: "Charm Combo · voice script", font: FONT, size: 16, color: SOFT })] })] }) },
    footers: { default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ children: [PageNumber.CURRENT], font: FONT, size: 16, color: SOFT })] })] }) },
    children,
  }],
});

Packer.toBuffer(doc).then(buf => {
  const f = path.join(outDir, "Charm_Combo_Voice_Script.docx");
  fs.writeFileSync(f, buf);
  console.log("wrote " + f);
});
