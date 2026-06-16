import * as React from "react";
import * as ReactDom from "react-dom";
import { Version } from "@microsoft/sp-core-library";
import {
    IPropertyPaneConfiguration,
    PropertyPaneTextField,
} from "@microsoft/sp-property-pane";
import { BaseClientSideWebPart } from "@microsoft/sp-webpart-base";

import LandingPortal from "./components/LandingPortal";
import { ILandingPortalProps } from "./components/ILandingPortalProps";

export interface ILandingPortalWebPartProps {
    title: string;
    ticketApiBaseUrl: string;
}

export default class LandingPortalWebPart
    extends BaseClientSideWebPart<ILandingPortalWebPartProps> {
    public render(): void {
        const element: React.ReactElement<ILandingPortalProps> = React
            .createElement(
                LandingPortal,
                {
                    title: this.properties.title || "Field Tech Portal",
                    siteUrl: this.context.pageContext.web.absoluteUrl,
                    context: this.context,
                    ticketApiBaseUrl: this.properties.ticketApiBaseUrl,
                },
            );

        ReactDom.render(element, this.domElement);
    }

    protected onDispose(): void {
        ReactDom.unmountComponentAtNode(this.domElement);
    }

    protected get dataVersion(): Version {
        return Version.parse("1.0");
    }

    protected getPropertyPaneConfiguration(): IPropertyPaneConfiguration {
        return {
            pages: [
                {
                    header: {
                        description: "Landing portal settings",
                    },
                    groups: [
                        {
                            groupName: "General",
                            groupFields: [
                                PropertyPaneTextField("title", {
                                    label: "Portal title",
                                }),
                                PropertyPaneTextField("ticketApiBaseUrl", {
                                    label: "Ticket API base URL",
                                }),
                            ],
                        },
                    ],
                },
            ],
        };
    }
}
