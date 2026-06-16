import * as React from "react";
import { INavNode } from "../../../models/INavNode";

import styles from "../styles/AnimatedNavMap.module.scss";

export interface IAnimatedNavMapProps {
    nodes: INavNode[];
}

const AnimatedNavMap: React.FC<IAnimatedNavMapProps> = ({ nodes }) => {
    return (
        <section className={styles.mapSection}>
            <div className={styles.mapCanvas}>
                {nodes.map((node) => (
                    <a
                        key={node.id}
                        href={node.url}
                        className={styles.node}
                        style={{ left: `${node.x}%`, top: `${node.y}%` }}
                        target={node.external ? "_blank" : "_self"}
                        rel={node.external ? "noopener noreferrer" : undefined}
                    >
                        <span className={styles.nodeIcon}>
                            {node.icon || "•"}
                        </span>
                        <span className={styles.nodeLabel}>{node.label}</span>
                        <span className={styles.nodeDescription}>
                            {node.description}
                        </span>
                    </a>
                ))}
            </div>
        </section>
    );
};

export default AnimatedNavMap;
