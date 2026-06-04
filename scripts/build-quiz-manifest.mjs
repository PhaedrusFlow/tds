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

const parseJsonFile = (raw, fileName) => {
    try {
        return JSON.parse(raw);
    } catch (error) {
        throw new Error(`Invalid JSON in ${fileName}: ${error.message}`);
    }
};

const isNonEmptyString = (value) =>
    typeof value === "string" && value.trim().length > 0;

const validateQuestion = (question, fileName, index) => {
    const label = `${fileName} question #${index + 1}`;

    if (
        typeof question !== "object" || question === null ||
        Array.isArray(question)
    ) {
        throw new Error(`${label} must be an object.`);
    }

    if (typeof question.id !== "number" && !isNonEmptyString(question.id)) {
        throw new Error(`${label} is missing a valid "id".`);
    }

    if (!isNonEmptyString(question.question)) {
        throw new Error(`${label} is missing a non-empty "question" string.`);
    }

    if (!Array.isArray(question.choices) || question.choices.length < 2) {
        throw new Error(
            `${label} must have a "choices" array with at least 2 items.`,
        );
    }

    for (let i = 0; i < question.choices.length; i += 1) {
        if (!isNonEmptyString(question.choices[i])) {
            throw new Error(
                `${label} choice #${i + 1} must be a non-empty string.`,
            );
        }
    }

    if (!isNonEmptyString(question.answer)) {
        throw new Error(`${label} is missing a non-empty "answer" string.`);
    }

    if (!question.choices.includes(question.answer)) {
        throw new Error(
            `${label} has an "answer" that does not match any choice.`,
        );
    }

    if (
        question.explanation !== undefined &&
        question.explanation !== null &&
        typeof question.explanation !== "string"
    ) {
        throw new Error(
            `${label} has an invalid "explanation"; it must be a string if provided.`,
        );
    }
};

const validateQuizData = (data, fileName) => {
    if (typeof data !== "object" || data === null || Array.isArray(data)) {
        throw new Error(`${fileName} must contain a top-level JSON object.`);
    }

    if (!isNonEmptyString(data.id)) {
        throw new Error(
            `${fileName} is missing a non-empty top-level "id" string.`,
        );
    }

    if (!isNonEmptyString(data.title)) {
        throw new Error(
            `${fileName} is missing a non-empty top-level "title" string.`,
        );
    }

    if (
        data.description !== undefined &&
        data.description !== null &&
        typeof data.description !== "string"
    ) {
        throw new Error(
            `${fileName} has an invalid "description"; it must be a string if provided.`,
        );
    }

    if (!Array.isArray(data.questions)) {
        throw new Error(
            `${fileName} is missing a top-level "questions" array.`,
        );
    }

    if (data.questions.length === 0) {
        throw new Error(`${fileName} has an empty "questions" array.`);
    }

    const seenIds = new Set();

    for (let i = 0; i < data.questions.length; i += 1) {
        const question = data.questions[i];
        validateQuestion(question, fileName, i);

        const key = String(question.id).trim();
        if (seenIds.has(key)) {
            throw new Error(
                `${fileName} has duplicate question id "${question.id}".`,
            );
        }
        seenIds.add(key);
    }
};

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
        const parsed = parseJsonFile(raw, fileName);

        validateQuizData(parsed, fileName);

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
    console.error(error.message || error);
    process.exit(1);
});

