import * as React from "react";
import { useEffect, useState } from "react";
import { ILandingPortalProps } from "./ILandingPortalProps";
import AnimatedNavMap from "./AnimatedNavMap";
import { mapData } from "../../../data/mapData";
import SalesforceTicketsService, {
    ISalesforceTicket,
} from "../../../common/services/SalesforceTicketsService";
import styles from "../styles/LandingPortal.module.scss";

const LandingPortal: React.FC<ILandingPortalProps> = ({
    title,
    siteUrl,
    context,
    ticketApiBaseUrl,
}) => {
    const [tickets, setTickets] = useState<ISalesforceTicket[]>([]);
    const [loading, setLoading] = useState<boolean>(false);
    const [ticketError, setTicketError] = useState<string>("");

    useEffect(() => {
        if (!ticketApiBaseUrl) {
            return;
        }

        SalesforceTicketsService.init(context, ticketApiBaseUrl);
        setLoading(true);

        SalesforceTicketsService.getMyTickets()
            .then((result) => {
                setTickets(result);
                setTicketError("");
            })
            .catch((error: Error) => {
                setTicketError(error.message);
            })
            .finally(() => {
                setLoading(false);
            });
    }, [context, ticketApiBaseUrl]);

    return (
        <div className={styles.portal}>
            <header className={styles.hero}>
                <p className={styles.eyebrow}>TDS Tech Training Tips</p>
                <h1 className={styles.title}>{title}</h1>
                <p className={styles.subtitle}>
                    Animated landing portal for training, tools, documents,
                    reporting, and future Salesforce-aligned field ticket
                    workflows.
                </p>
                <p className={styles.siteLink}>
                    <a href={siteUrl}>Open site</a>
                </p>
            </header>

            <AnimatedNavMap nodes={mapData} />

            <section className={styles.ticketPanel}>
                <div className={styles.ticketHeader}>
                    <h2>My tickets</h2>
                    <p>Starter panel for Salesforce-connected field work.</p>
                </div>

                {!ticketApiBaseUrl && (
                    <div className={styles.ticketState}>
                        API not configured yet. Add a backend URL to load
                        assigned tickets.
                    </div>
                )}

                {ticketApiBaseUrl && loading && (
                    <div className={styles.ticketState}>Loading tickets…</div>
                )}

                {ticketApiBaseUrl && ticketError && (
                    <div className={styles.ticketError}>{ticketError}</div>
                )}

                {ticketApiBaseUrl && !loading && !ticketError &&
                    tickets.length === 0 && (
                        <div className={styles.ticketState}>
                            No tickets returned.
                        </div>
                    )}

                {tickets.length > 0 && (
                    <div className={styles.ticketList}>
                        {tickets.map((ticket) => (
                            <article
                                key={ticket.id}
                                className={styles.ticketCard}
                            >
                                <div className={styles.ticketTopRow}>
                                    <strong>{ticket.ticketNumber}</strong>
                                    <span className={styles.status}>
                                        {ticket.status}
                                    </span>
                                </div>
                                <h3>{ticket.title}</h3>
                                {ticket.customerName && (
                                    <p>{ticket.customerName}</p>
                                )}
                                {ticket.address && <p>{ticket.address}</p>}
                                {ticket.appointmentWindow && (
                                    <p>{ticket.appointmentWindow}</p>
                                )}
                            </article>
                        ))}
                    </div>
                )}
            </section>
        </div>
    );
};

export default LandingPortal;
