# `.yo-rc.json` options for `@microsoft/generator-sharepoint`

This document summarizes the commonly used configuration keys that can appear under the `@microsoft/generator-sharepoint` namespace in `.yo-rc.json` for a SharePoint Framework (SPFx) project. The file is Yeoman generator metadata that stores scaffold choices and generator state, not runtime application configuration.

## Overview

The `.yo-rc.json` file is a Yeoman-managed JSON file where generator configuration is stored under a namespaced key, such as `@microsoft/generator-sharepoint`.[1] In SPFx projects, it typically captures the choices made during project creation, including solution identity, environment, package manager, component type, and framework selection.

## Alphabetical options

| Option | Type | Purpose | Notes |
|---|---|---|---|
| `componentDescription` | string | Describes the generated component. | Commonly reflects the Yeoman prompt for the web part or extension description. |
| `componentName` | string | Stores the generated component name. | Commonly matches the scaffolded web part or extension name. |
| `componentType` | string | Identifies the SPFx component type being scaffolded. | Common values include `webpart`; other generator scenarios may use extension-related values depending on the selected template. |
| `environment` | string | Indicates the target SharePoint environment. | For SharePoint Online projects this is typically `spo`. |
| `framework` | string | Records the client framework selected during scaffolding. | Common values include `react` or no-framework style selections depending on the generator path used. |
| `isCreatingSolution` | boolean | Indicates whether the generator created a full SPFx solution. | This is typically `true` for a standard scaffolded SPFx project. |
| `libraryId` | string | Stores the GUID for the generated solution. | This acts as the scaffolded solution identity captured by the generator state. |
| `libraryName` | string | Stores the solution or library name chosen at scaffold time. | Usually matches the project name used when generating the SPFx solution. |
| `packageManager` | string | Records the package manager chosen during generation. | Commonly `npm`; other Yeoman flows can store the selected package manager here. |
| `version` | string | Stores the version of `@microsoft/generator-sharepoint` used to scaffold the project. | This helps indicate which generator version created the solution structure.|

## Example

```json
{
  "@microsoft/generator-sharepoint": {
    "version": "1.21.1",
    "libraryName": "sharepoint-portal-spfx",
    "libraryId": "11111111-2222-3333-4444-555555555555",
    "environment": "spo",
    "packageManager": "npm",
    "isCreatingSolution": true,
    "componentType": "webpart",
    "componentName": "LandingPortal",
    "componentDescription": "Animated SharePoint landing portal for training, tools, reports, and ticket workflows.",
    "framework": "react"
  }
}
```

## What this file is not for

`.yo-rc.json` should not be used as the main place for deployment settings, runtime API endpoints, package metadata, or web part behavior settings. Those belong in files such as `config/package-solution.json`, `config/config.json`, `config/serve.json`, the web part manifest, and source-level configuration files under `src/`.

## Practical guidance

For most SPFx projects, it is best to keep `.yo-rc.json` minimal and accurate to the original scaffold choices rather than using it as a custom configuration registry. The most useful fields to preserve are the generator `version`, the solution identity fields, the `componentType`, and the chosen framework-related fields such as `componentName`, `componentDescription`, and `framework`.

```text
sharepoint-portal-spfx/
├── .github/
├── config/
│   ├── config.json
│   ├── copy-assets.json
│   ├── deploy-azure-storage.json
│   ├── package-solution.json
│   └── serve.json
├── sharepoint/
│   └── assets/
│       └── clientside-instance.xml
├── src/
│   └── webparts/
│       └── portalDashboard/
│           ├── PortalDashboardWebPart.ts
│           ├── PortalDashboardWebPart.manifest.json
│           ├── components/
│           │   ├── PortalDashboard.tsx
│           │   ├── IPortalDashboardProps.ts
│           │   ├── DashboardHeader.tsx
│           │   ├── ExcelEmbed.tsx
│           │   ├── QuickLinks.tsx
│           │   └── AppLauncher.tsx
│           ├── loc/
│           │   ├── en-us.js
│           │   └── mystrings.d.ts
│           └── styles/
│               └── PortalDashboard.module.scss
├── temp/
├── release/
│   └── sharepoint-portal.sppkg
├── package.json
├── tsconfig.json
├── gulpfile.js
├── .yo-rc.json
├── README.md
└── .gitignore
```
