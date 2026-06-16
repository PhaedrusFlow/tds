export interface INavNode {
    id: string;
    label: string;
    description: string;
    url: string;
    x: number;
    y: number;
    external?: boolean;
    icon?: string;
}
