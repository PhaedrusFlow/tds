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
