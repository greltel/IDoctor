/*
 * Runs the transpiled ABAP Unit tests and prints a readable report.
 *
 *   node transpiler/run_unit_tests.mjs [--filter <text>] [--verbose]
 *
 * Why not the generated output/index.mjs? It stops at the first failure and shows the
 * JavaScript error object instead of the ABAP message. This runner reads the test list the
 * transpiler generated, runs setup, the test method and teardown of every test itself, prints
 * the ABAP message of a failure, and exits with 1 if any test failed or no test ran.
 */
import fs from "fs";
import path from "path";
import {fileURLToPath} from "url";

const here = path.dirname(fileURLToPath(import.meta.url));
const outputFolder = path.resolve(here, "..", "output");

const argv = process.argv.slice(2);
const verbose = argv.includes("--verbose");
const filterIndex = argv.indexOf("--filter");
const filter = filterIndex >= 0 ? (argv[filterIndex + 1] ?? "").toUpperCase() : "";

function readTestList() {
  const source = fs.readFileSync(path.join(outputFolder, "index.mjs"), "utf8");
  const tests = [];
  const entry = /ret\.push\(\{objectName: "([^"]+)",\s*localClass: "([^"]+)",\s*methods: (\[[^\]]*\]),\s*riskLevel: "[^"]*",\s*filename: "([^"]+)"\}\)/g;
  for (const match of source.matchAll(entry)) {
    const [, objectName, localClass, methodsJson, filename] = match;
    const methods = JSON.parse(methodsJson).filter(m => m.skip !== true).map(m => m.name);
    if (methods.length > 0) {
      tests.push({objectName, localClass: localClass.toUpperCase(), methods, filename});
    }
  }
  return tests;
}

async function exceptionText(error) {
  try {
    if (typeof error.if_message$get_text === "function") {
      return (await error.if_message$get_text({result: 1})).get();
    }
  } catch {
    // fall through
  }
  return "";
}

function location(error) {
  const extra = error?.EXTRA_CX;
  return extra ? `${extra.INTERNAL_FILENAME}:${extra.INTERNAL_LINE}` : "";
}

async function run() {
  await import(path.join(outputFolder, "init.mjs"));
  const abap = globalThis.abap;

  const tests = readTestList().filter(t =>
    filter === "" || t.objectName.includes(filter) || t.localClass.includes(filter));
  const files = new Set(tests.map(t => t.filename));
  for (const file of files) {
    await import(path.join(outputFolder, file));
  }

  let passed = 0;
  let failed = 0;
  const failures = [];

  for (const test of tests) {
    const testClass = abap.Classes[`CLAS-${test.objectName}-${test.localClass}`];
    if (testClass === undefined) {
      console.log(`?? ${test.objectName}: ${test.localClass} not found`);
      continue;
    }
    if (testClass.class_setup) {
      await testClass.class_setup();
    }
    for (const method of test.methods) {
      const label = `${test.objectName}: ${test.localClass}->${method}`;
      const instance = await (new testClass()).constructor_();
      const call = async (name) => {
        const fn = instance.FRIENDS_ACCESS_INSTANCE?.[name] ?? instance[name];
        if (fn) {
          await fn.call(instance);
        }
      };
      try {
        await call("setup");
        await call(method);
        await call("teardown");
        passed++;
        if (verbose) {
          console.log(`ok   ${label}`);
        }
      } catch (error) {
        failed++;
        let detail;
        if (abap.Classes["KERNEL_CX_ASSERT"] && error instanceof abap.Classes["KERNEL_CX_ASSERT"]) {
          detail = `assertion failed: ${error.msg?.get?.() ?? ""}`
            + ` | expected: ${error.expected?.get?.() ?? ""} | actual: ${error.actual?.get?.() ?? ""}`;
        } else if (abap.Classes["CX_ROOT"] && error instanceof abap.Classes["CX_ROOT"]) {
          detail = `${error.constructor.INTERNAL_NAME}: ${await exceptionText(error)} ${location(error)}`;
          if (verbose && error.stack) {
            detail += `\n     ${error.stack.split("\n").slice(0, 6).join("\n     ")}`;
          }
        } else {
          detail = `${error?.stack ?? error}`;
        }
        failures.push({label, detail});
        console.log(`FAIL ${label}\n     ${detail}`);
        try {
          await call("teardown");
        } catch {
          // teardown after a failure is best effort
        }
      }
    }
    if (testClass.class_teardown) {
      await testClass.class_teardown();
    }
  }

  console.log(`\n${passed} passed, ${failed} failed, ${passed + failed} total`);
  if (passed + failed === 0) {
    // a green run without tests would hide that the test list could not be read
    console.log(filter === "" ? "No tests ran: the test list in output/index.mjs was not found"
                              : `No tests ran: nothing matches --filter ${filter}`);
  }
  process.exit(failed === 0 && passed > 0 ? 0 : 1);
}

run().catch(error => {
  console.error(error);
  process.exit(2);
});
