import {
    IPropertyPaneConfiguration,
    PropertyPaneTextField,
} from "@microsoft/sp-property-pane";

import * as strings from "LandingPortalWebPartStrings";
import { ILandingPortalWebPartProps } from "../LandingPortalWebPart";

export function getPropertyPaneConfiguration(
    properties: ILandingPortalWebPartProps,
): IPropertyPaneConfiguration {
    return {
        pages: [
            {
                header: {
                    description: strings.PropertyPaneDescription,
                },
                groups: [
                    {
                        groupName: strings.BasicGroupName,
                        groupFields: [
                            PropertyPaneTextField("title", {
                                label: strings.TitleFieldLabel,
                                value: properties.title,
                            }),
                            PropertyPaneTextField("ticketApiBaseUrl", {
                                label: strings.TicketApiBaseUrlFieldLabel,
                                value: properties.ticketApiBaseUrl,
                            }),
                        ],
                    },
                ],
            },
        ],
    };
}
