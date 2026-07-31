import { promises as fs } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDirectory, "..");

const quizzesDirectory = path.join(repoRoot, "ta", "quizzes");
const dataDirectory = path.join(quizzesDirectory, "data");
const manifestPath = path.join(dataDirectory, "manifest.json");
const mockQuizPath = path.join(repoRoot, "ta", "mock", "pretest-c.json");

const isQuizFile = (name) =>
    name.toLowerCase().endsWith(".json") && name !== "manifest.json";

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
        const message =
            error instanceof Error ? error.message : String(error);

        throw new Error(`Invalid JSON in ${fileName}: ${message}`);
    }
};

const readQuizFile = async (filePath) => {
    const fileName = path.basename(filePath);
    const raw = await fs.readFile(filePath, "utf8");
    const parsed = parseJsonFile(raw, fileName);

    if (
        parsed === null ||
        typeof parsed !== "object" ||
        Array.isArray(parsed)
    ) {
        throw new Error(`${fileName} must contain a top-level JSON object.`);
    }

    if (!Array.isArray(parsed.questions)) {
        throw new Error(`${fileName} must contain a questions array.`);
    }

    return parsed;
};

const quizIdentity = (quiz, fileName) => {
    const filenameSlug = slugFromFilename(fileName);

    return {
        id:
            typeof quiz.id === "string" && quiz.id.trim()
                ? quiz.id.trim()
                : filenameSlug,
        title:
            typeof quiz.title === "string" && quiz.title.trim()
                ? quiz.title.trim()
                : titleFromSlug(filenameSlug),
    };
};

const addUniqueEntry = (manifest, knownIds, entry) => {
    if (knownIds.has(entry.id)) {
        throw new Error(`Duplicate quiz id in manifest: ${entry.id}`);
    }

    knownIds.add(entry.id);
    manifest.push(entry);
};

const main = async () => {
    const entries = await fs.readdir(dataDirectory, {
        withFileTypes: true,
    });

    const quizFiles = entries
        .filter((entry) => entry.isFile() && isQuizFile(entry.name))
        .map((entry) => entry.name)
        .sort((left, right) => left.localeCompare(right));

    const manifest = [];
    const knownIds = new Set();

    for (const fileName of quizFiles) {
        const filePath = path.join(dataDirectory, fileName);
        const quiz = await readQuizFile(filePath);
        const { id, title } = quizIdentity(quiz, fileName);

        addUniqueEntry(manifest, knownIds, {
            id,
            title,
            description: descriptionFromData(quiz),
            file: `data/${fileName}`,
            questionCount: quiz.questions.length,
            mode: "practice",
            requiresPassword: false,
        });
    }

    const mockQuiz = await readQuizFile(mockQuizPath);
    const mockFileName = path.basename(mockQuizPath);
    const mockIdentity = quizIdentity(mockQuiz, mockFileName);

    addUniqueEntry(manifest, knownIds, {
        id: mockIdentity.id,
        title: mockIdentity.title,
        description: descriptionFromData(mockQuiz),
        file: "data/pretest-c.json",
        questionCount: mockQuiz.questions.length,
        mode: "mock",
        requiresPassword: true,
    });

    await fs.writeFile(
        manifestPath,
        `${JSON.stringify(manifest, null, 2)}\n`,
        "utf8",
    );

    console.log(
        `Wrote ${manifest.length} quiz entries to ${manifestPath}`,
    );
};

main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
});
