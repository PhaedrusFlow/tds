import { WebPartContext } from "@microsoft/sp-webpart-base";

export interface ILandingPortalProps {
    title: string;
    siteUrl: string;
    context: WebPartContext;
    ticketApiBaseUrl?: string;
}
