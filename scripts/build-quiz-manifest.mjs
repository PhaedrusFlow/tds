import { promises as fs } from "node:fs";
import path from "node:path";

const repoRoot = process.cwd();
const dataDir = path.join(
    repoRoot,
    "successbuilder",
    "development",
    "ta",
    "quizzes",
    "data",
);
const manifestPath = path.join(dataDir, "manifest.json");

const isQuizFile = (name) => name.endsWith(".json") && name !== "manifest.json";

const slugFromFilename = (name) => name.replace(/\.json$/i, "");

const titleFromSlug = (slug) =>
    slug
        .split("-")
        .map((part) => (part ? part[0].toUpperCase() + part.slice(1) : part))
        .join(" ");

const descriptionFromData = (data) =>
    typeof data.description === "string" && data.description.trim()
        ? data.description.trim()
        : "Quiz loaded from JSON question bank.";

const main = async () => {
    const entries = await fs.readdir(dataDir, { withFileTypes: true });

    const files = entries
        .filter((entry) => entry.isFile() && isQuizFile(entry.name))
        .map((entry) => entry.name)
        .sort((a, b) => a.localeCompare(b));

    const manifest = [];

    for (const fileName of files) {
        const filePath = path.join(dataDir, fileName);
        const raw = await fs.readFile(filePath, "utf8");
        const parsed = JSON.parse(raw);

        const slug = typeof parsed.id === "string" && parsed.id.trim()
            ? parsed.id.trim()
            : slugFromFilename(fileName);

        const title = typeof parsed.title === "string" && parsed.title.trim()
            ? parsed.title.trim()
            : titleFromSlug(slugFromFilename(fileName));

        const questions = Array.isArray(parsed.questions)
            ? parsed.questions
            : [];

        manifest.push({
            id: slug,
            title,
            description: descriptionFromData(parsed),
            file: `data/${fileName}`,
            questionCount: questions.length,
        });
    }

    await fs.writeFile(
        manifestPath,
        `${JSON.stringify(manifest, null, 2)}\n`,
        "utf8",
    );
    console.log(`Wrote ${manifest.length} quiz entries to ${manifestPath}`);
};

main().catch((error) => {
    console.error(error);
    process.exit(1);
});
