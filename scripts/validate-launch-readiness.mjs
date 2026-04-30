#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const failures = [];
const warnings = [];

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), 'utf8');
}

function fail(message) {
  failures.push(message);
}

function warn(message) {
  warnings.push(message);
}

function assert(condition, message) {
  if (!condition) fail(message);
}

function setEquals(a, b) {
  return a.size === b.size && [...a].every((value) => b.has(value));
}

function recursiveProductIDs(value, ids = new Set()) {
  if (Array.isArray(value)) {
    for (const item of value) recursiveProductIDs(item, ids);
  } else if (value && typeof value === 'object') {
    if (typeof value.productID === 'string') ids.add(value.productID);
    for (const child of Object.values(value)) recursiveProductIDs(child, ids);
  }
  return ids;
}

function shopCatalogIDs(value) {
  const ids = new Set();
  for (const key of ['bundles', 'gemBundles', 'perkBundles', 'freePerks']) {
    for (const item of value[key] ?? []) {
      if (typeof item.id === 'string') ids.add(item.id);
    }
  }
  return ids;
}

const iapSwift = read('Packages/GameCore/Sources/GameCore/Models/IAPProduct.swift');
const codeIDs = new Set([...iapSwift.matchAll(/id:\s*"([^"]+)"/g)].map((match) => match[1]).filter((id) => id.startsWith('com.game2244.')));
const docsIDs = new Set([...read('Docs/IAP_CATALOG.md').matchAll(/`(com\.game2244\.[^`]+)`/g)].map((match) => match[1]));
const storeKitIDs = recursiveProductIDs(JSON.parse(read('2244/game2244/Configuration.storekit')));
const shopIDs = shopCatalogIDs(JSON.parse(read('2244/game2244/JSON/2244_shop_catalog.json')));
const scheme = read('2244/game2244.xcodeproj/xcshareddata/xcschemes/game2244.xcscheme');
const storeKitSchemeReference = scheme.match(/<StoreKitConfigurationFileReference\s+identifier = "([^"]+)"/);

assert(codeIDs.size === 13, `Expected 13 IAP products in code, found ${codeIDs.size}.`);
assert(setEquals(codeIDs, docsIDs), 'Docs/IAP_CATALOG.md product IDs differ from IAPProduct.allProducts.');
assert(setEquals(codeIDs, storeKitIDs), 'Configuration.storekit product IDs differ from IAPProduct.allProducts.');
assert([...shopIDs].every((id) => codeIDs.has(id)), 'Shop JSON contains an ID that is not in IAPProduct.allProducts.');
assert(!scheme.includes('storeKitConfigurationFileReference ='), 'Xcode scheme uses the obsolete inline StoreKit configuration attribute.');
assert(Boolean(storeKitSchemeReference), 'Xcode scheme does not enable the local StoreKit configuration file.');
if (storeKitSchemeReference) {
  const resolvedStoreKitPath = path.resolve(root, '2244/game2244.xcodeproj', storeKitSchemeReference[1]);
  const expectedStoreKitPath = path.resolve(root, '2244/game2244/Configuration.storekit');
  assert(resolvedStoreKitPath === expectedStoreKitPath, 'Xcode scheme StoreKit configuration path does not resolve to Configuration.storekit.');
  assert(fs.existsSync(resolvedStoreKitPath), 'Xcode scheme StoreKit configuration path does not exist.');
}

const rootRules = read('firestore.rules');
const deployRules = read('firebase/firestore.rules');
assert(rootRules === deployRules, 'firestore.rules and firebase/firestore.rules are not synchronized.');
for (const snippet of [
  'match /players/{uid}',
  'allow create, update: if isOwner(uid)',
  'match /progress/{document=**}',
  'match /leaderboards/{board=**}',
  'match /purchases/{txnId}',
  'match /reports/{id}',
  'request.resource.data.reporterId == request.auth.uid',
  'match /leaderboards/{boardId}',
  'match /scores/{uid}',
  'allow write: if false',
]) {
  assert(rootRules.includes(snippet), `Firestore rules missing required snippet: ${snippet}`);
}

const project = read('2244/game2244.xcodeproj/project.pbxproj');
assert(project.includes('PRODUCT_BUNDLE_IDENTIFIER = com.ideabloomlabs.game2244;'), 'App target bundle identifier is not com.ideabloomlabs.game2244.');
assert(project.includes('IPHONEOS_DEPLOYMENT_TARGET = 26.0;'), 'iOS deployment target is not 26.0.');
assert(project.includes('ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;'), 'App icon catalog is not configured.');
assert(project.includes('CODE_SIGN_ENTITLEMENTS = game2244.entitlements;'), 'App target entitlements file is not configured.');
const buildEntitlements = read('2244/game2244.entitlements');
const nestedEntitlements = read('2244/game2244/game2244.entitlements');
assert(buildEntitlements === nestedEntitlements, 'Xcode and nested entitlement files are not synchronized.');
assert(buildEntitlements.includes('com.apple.developer.game-center'), 'Game Center entitlement is missing.');

const infoPlist = read('2244/game2244/Info.plist');
for (const key of [
  'CFBundleDisplayName',
  'NSUserTrackingUsageDescription',
  'GADApplicationIdentifier',
  'SKAdNetworkItems',
]) {
  assert(infoPlist.includes(`<key>${key}</key>`), `Info.plist missing ${key}.`);
}

const privacy = read('2244/game2244/PrivacyInfo.xcprivacy');
assert(privacy.includes('NSPrivacyAccessedAPICategoryUserDefaults'), 'Privacy manifest missing UserDefaults required-reason API.');
assert(privacy.includes('CA92.1'), 'Privacy manifest missing UserDefaults reason CA92.1.');

const gitignore = read('.gitignore');
assert(gitignore.includes('GoogleService-Info.plist'), '.gitignore does not ignore GoogleService-Info.plist.');
try {
  const tracked = execFileSync('git', ['ls-files', '2244/game2244/GoogleService-Info.plist'], {
    cwd: root,
    encoding: 'utf8',
  }).trim();
  if (tracked) {
    fail('2244/game2244/GoogleService-Info.plist is tracked. Remove it with git rm --cached before release.');
  }
} catch {
  warn('Could not check whether GoogleService-Info.plist is tracked by git.');
}

for (const message of warnings) {
  console.warn(`WARN: ${message}`);
}

if (failures.length > 0) {
  for (const message of failures) {
    console.error(`FAIL: ${message}`);
  }
  process.exit(1);
}

console.log('Launch readiness validation passed.');
