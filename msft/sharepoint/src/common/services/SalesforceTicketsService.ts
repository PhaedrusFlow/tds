import { AadHttpClient, HttpClientResponse } from "@microsoft/sp-http";
import { WebPartContext } from "@microsoft/sp-webpart-base";

export interface ISalesforceTicket {
    id: string;
    ticketNumber: string;
    title: string;
    status: string;
    customerName?: string;
    address?: string;
    appointmentWindow?: string;
}

export default class SalesforceTicketsService {
    private static _context: WebPartContext;
    private static _apiBaseUrl: string;

    public static init(context: WebPartContext, apiBaseUrl: string): void {
        SalesforceTicketsService._context = context;
        SalesforceTicketsService._apiBaseUrl = apiBaseUrl.replace(/\/$/, "");
    }

    public static async getMyTickets(): Promise<ISalesforceTicket[]> {
        if (!SalesforceTicketsService._context) {
            throw new Error("SalesforceTicketsService not initialized.");
        }

        if (!SalesforceTicketsService._apiBaseUrl) {
            return [];
        }

        const client: AadHttpClient = await SalesforceTicketsService._context
            .aadHttpClientFactory.getClient(
                SalesforceTicketsService._apiBaseUrl,
            );

        const response: HttpClientResponse = await client.get(
            `${SalesforceTicketsService._apiBaseUrl}/api/tickets/my`,
            AadHttpClient.configurations.v1,
        );

        if (!response.ok) {
            throw new Error(
                `Ticket API request failed: ${response.status} ${response.statusText}`,
            );
        }

        const data = await response.json();
        return (data?.value || data || []) as ISalesforceTicket[];
    }
}
