type Nullable<T> = T | null | undefined
declare function KtSingleton<T>(): T & (abstract new() => any);
/** @deprecated  */
export declare const initHook: {
    get(): any;
};
export declare class WebLage {
    constructor();
    empfangen(text: string): void;
    quellen(jetztMs: number, zoom: number, ausgeblendeteEbenen: Array<string>, ausgeblendeteZielarten: Array<string>, ausgeblendeteGruppen: Array<string>): string;
    oepnvFahrzeuge(jetztMs: number, ausgeblendeteEbenen: Array<string>): string;
    stilAdresse(grundkarte: string, dunkel: boolean, dreiD: boolean): string;
    get quelleOepnvFahrzeuge(): string;
    kurzinfo(schluessel: string, jetztMs: number): Nullable<string>;
    symbolFuerBild(bildname: string): Nullable<string>;
}
export declare namespace WebLage {
    /** @deprecated $metadata$ is used for internal purposes, please don't use it in your code, because it can be removed at any moment */
    namespace $metadata$ {
        const constructor: abstract new () => WebLage;
    }
}