declare interface ILandingPortalWebPartStrings {
    PropertyPaneDescription: string;
    BasicGroupName: string;
    TitleFieldLabel: string;
    TicketApiBaseUrlFieldLabel: string;
}

declare module "LandingPortalWebPartStrings" {
    const strings: ILandingPortalWebPartStrings;
    export = strings;
}
