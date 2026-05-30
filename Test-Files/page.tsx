import Image from 'next/image';
import { Markdown } from '../components/Markdown';
import { BlogPosts } from './components/posts';
import { getBlogPost, getPageSections, getPostCoverImage, getSocialEntries } from '@/lib/notion';

export const revalidate = 300;

type ParsedLink = {
    text: string;
    url: string;
};

type ParsedMarkdown = {
    pretitle: string;
    heading: string;
    paragraphs: string[];
    links: ParsedLink[];
    listItems: string[];
};

type AboutBlock = {
    title: string;
    items: string[];
    textBlocks: string[][];
};

const SOCIAL_PATTERNS: Array<{ platform: string; pattern: RegExp }> = [
    { platform: 'instagram', pattern: /instagram\.com/i },
    { platform: 'linkedin', pattern: /linkedin\.com/i },
    { platform: 'youtube', pattern: /youtube\.com|youtu\.be/i },
    { platform: 'vimeo', pattern: /vimeo\.com/i },
];

function parseMarkdown(content: string): ParsedMarkdown {
    const lines = content.split('\n').filter((l) => l.trim());
    const h1Index = lines.findIndex((l) => l.startsWith('# '));
    const afterH1 = h1Index >= 0 ? lines.slice(h1Index + 1) : lines;
    const pretitleLine = lines.find((l) => /^(####|###)\s+/.test(l.trim()));

    return {
        pretitle: pretitleLine?.trim().replace(/^(####|###)\s+/, '').trim() || '',
        heading: lines.find((l) => l.startsWith('# '))?.replace(/^# /, '') || '',
        paragraphs: afterH1.filter(
            (l) =>
                !l.startsWith('#') &&
                !l.startsWith('!') &&
                !l.startsWith('[') &&
                !l.startsWith('-') &&
                !l.startsWith('*')
        ),
        links: (() => {
            const byUrl = new Map<string, ParsedLink>();

            for (const m of content.matchAll(/\[([^\]]+)\]\(([^)]+)\)/g)) {
                const text = m[1]?.trim();
                const url = m[2]?.trim();

                if (!url) {
                    continue;
                }

                byUrl.set(url, { text: text || url, url });
            }

            for (const m of content.matchAll(/https?:\/\/[^\s)]+/g)) {
                const url = m[0]?.trim();

                if (!url || byUrl.has(url)) {
                    continue;
                }

                byUrl.set(url, { text: url, url });
            }

            return [...byUrl.values()];
        })(),
        listItems: lines
            .filter((l) => l.startsWith('- ') || l.startsWith('* '))
            .map((l) => l.replace(/^[-*] /, '')),
    };
}

function parseAboutBlocks(content: string): AboutBlock[] {
    const lines = content.split('\n').map((line) => line.trim());
    const blocks: AboutBlock[] = [];
    let current: AboutBlock | null = null;
    let currentTextGroup: string[] = [];

    const flushCurrentTextGroup = () => {
        if (!current) {
            currentTextGroup = [];
            return;
        }

        if (currentTextGroup.length > 0) {
            current.textBlocks.push(currentTextGroup);
            currentTextGroup = [];
        }
    };

    for (let i = 0; i < lines.length; i += 1) {
        const line = lines[i];
        const nextLine = lines[i + 1] || '';

        if (line.startsWith('<!--')) {
            continue;
        }

        if (!line) {
            flushCurrentTextGroup();
            continue;
        }

        if (line.startsWith('#')) {
            flushCurrentTextGroup();

            if (current && (current.items.length > 0 || current.textBlocks.length > 0)) {
                blocks.push(current);
            }

            current = {
                title: line.replace(/^#+\s*/, '').trim(),
                items: [],
                textBlocks: [],
            };
            continue;
        }

        if (line.startsWith('- ') || line.startsWith('* ')) {
            flushCurrentTextGroup();

            if (!current) {
                current = { title: 'Details', items: [], textBlocks: [] };
            }

            current.items.push(line.replace(/^[-*]\s*/, '').trim());
            continue;
        }

        if (!current) {
            continue;
        }

        currentTextGroup.push(line);

        if (currentTextGroup.length === 2) {
            flushCurrentTextGroup();
            continue;
        }

        if (
            currentTextGroup.length === 1 &&
            (!nextLine ||
                nextLine.startsWith('#') ||
                nextLine.startsWith('- ') ||
                nextLine.startsWith('* '))
        ) {
            flushCurrentTextGroup();
        }
    }

    flushCurrentTextGroup();

    if (current && (current.items.length > 0 || current.textBlocks.length > 0)) {
        blocks.push(current);
    }

    return blocks;
}

function platformFromUrl(url: string): string | null {
    const match = SOCIAL_PATTERNS.find(({ pattern }) => pattern.test(url));
    return match ? match.platform : null;
}

function SocialIcon({ platform }: { platform: string }) {
    if (platform === 'instagram') {
        return (
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" style={{ fill: 'rgba(255, 255, 255, 1)', transform: 'none' }}>
                <path d="M11.999,7.377c-2.554,0-4.623,2.07-4.623,4.623c0,2.554,2.069,4.624,4.623,4.624c2.552,0,4.623-2.07,4.623-4.624 C16.622,9.447,14.551,7.377,11.999,7.377L11.999,7.377z M11.999,15.004c-1.659,0-3.004-1.345-3.004-3.003 c0-1.659,1.345-3.003,3.004-3.003s3.002,1.344,3.002,3.003C15.001,13.659,13.658,15.004,11.999,15.004L11.999,15.004z" />
                <circle cx="16.806" cy="7.207" r="1.078" />
                <path d="M20.533,6.111c-0.469-1.209-1.424-2.165-2.633-2.632c-0.699-0.263-1.438-0.404-2.186-0.42 c-0.963-0.042-1.268-0.054-3.71-0.054s-2.755,0-3.71,0.054C7.548,3.074,6.809,3.215,6.11,3.479C4.9,3.946,3.945,4.902,3.477,6.111 c-0.263,0.7-0.404,1.438-0.419,2.186c-0.043,0.962-0.056,1.267-0.056,3.71c0,2.442,0,2.753,0.056,3.71 c0.015,0.748,0.156,1.486,0.419,2.187c0.469,1.208,1.424,2.164,2.634,2.632c0.696,0.272,1.435,0.426,2.185,0.45 c0.963,0.042,1.268,0.055,3.71,0.055s2.755,0,3.71-0.055c0.747-0.015,1.486-0.157,2.186-0.419c1.209-0.469,2.164-1.424,2.633-2.633 c0.263-0.7,0.404-1.438,0.419-2.186c0.043-0.962,0.056-1.267,0.056-3.71s0-2.753-0.056-3.71C20.941,7.57,20.801,6.819,20.533,6.111z M19.315,15.643c-0.007,0.576-0.111,1.147-0.311,1.688c-0.305,0.787-0.926,1.409-1.712,1.711c-0.535,0.199-1.099,0.303-1.67,0.311 c-0.95,0.044-1.218,0.055-3.654,0.055c-2.438,0-2.687,0-3.655-0.055c-0.569-0.007-1.135-0.112-1.669-0.311 c-0.789-0.301-1.414-0.923-1.719-1.711c-0.196-0.534-0.302-1.099-0.311-1.669c-0.043-0.95-0.053-1.218-0.053-3.654 c0-2.437,0-2.686,0.053-3.655c0.007-0.576,0.111-1.146,0.311-1.687c0.305-0.789,0.93-1.41,1.719-1.712 c0.534-0.198,1.1-0.303,1.669-0.311c0.951-0.043,1.218-0.055,3.655-0.055c2.437,0,2.687,0,3.654,0.055 c0.571,0.007,1.135,0.112,1.67,0.311c0.786,0.303,1.407,0.925,1.712,1.712c0.196,0.534,0.302,1.099,0.311,1.669 c0.043,0.951,0.054,1.218,0.054,3.655c0,2.436,0,2.698-0.043,3.654H19.315z" />
            </svg>
        );
    }

    if (platform === 'linkedin') {
        return (
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" style={{ fill: 'rgba(255, 255, 255, 1)', transform: 'none' }}>
                <path d="M6.94 8.5a1.56 1.56 0 1 1 0-3.12 1.56 1.56 0 0 1 0 3.12zM5.5 10h2.88v8.5H5.5V10zm4.5 0h2.76v1.16h.04c.38-.73 1.33-1.5 2.74-1.5 2.93 0 3.46 1.93 3.46 4.44v4.4h-2.88v-3.9c0-.93-.02-2.12-1.29-2.12-1.3 0-1.5 1.01-1.5 2.06v3.96H10V10z" />
            </svg>
        );
    }

    if (platform === 'youtube') {
        return (
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" style={{ fill: 'rgba(255, 255, 255, 1)', transform: 'none' }}>
                <path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z" />
            </svg>
        );
    }

    if (platform === 'vimeo') {
        return (
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" style={{ fill: 'rgba(255, 255, 255, 1)', transform: 'none' }}>
                <path d="M22.396 7.164c-.093 2.026-1.507 4.8-4.245 8.32C15.322 19.161 12.928 21 10.988 21c-1.214 0-2.24-.72-3.08-2.16-1.026-3.84-2.15-7.84-3.226-7.84-.28 0-.98.373-2.1 1.12l-1.353-1.68c1.352-1.26 2.66-2.52 3.826-3.64C6.393 5.6 7.28 5.04 7.7 5.04c1.12 0 1.82 1.213 2.1 3.64 1.12 7.093 1.633 8.307 2.473 8.307.746 0 2.146-2.147 4.2-6.44.84-1.68 1.26-2.753 1.26-3.22 0-1.026-.653-1.54-1.96-1.54-.56 0-1.12.14-1.68.42C15.348 3.033 17.074 2 19.314 2c1.96 0 2.986 1.726 3.082 5.164z" />
            </svg>
        );
    }

    return (
        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" style={{ fill: 'rgba(255, 255, 255, 1)', transform: 'none' }}>
            <path d="M11 14.59V20a1 1 0 1 0 2 0v-5.41l1.3 1.3a1 1 0 1 0 1.4-1.42l-3-3a1 1 0 0 0-1.4 0l-3 3a1 1 0 0 0 1.4 1.42z" />
            <path d="M12 2a9 9 0 0 0-9 9c0 4.97 4.03 9 9 9a1 1 0 1 0 0-2 7 7 0 1 1 7-7 1 1 0 1 0 2 0c0-4.97-4.03-9-9-9z" />
        </svg>
    );
}

export default async function Home() {
    const sections = await getPageSections();
    const socialEntries = await getSocialEntries();
    const sectionContents = await Promise.all(sections.map((s) => getBlogPost(s.id)));
    const contentMap = Object.fromEntries(
        sections.map((s, i) => [s.name.toLowerCase(), sectionContents[i]])
    );

    const introSection = sections.find((s) => s.name.toLowerCase() === 'intro');
    const worksSection = sections.find((s) => s.name.toLowerCase() === 'works');
    const aboutSection = sections.find((s) => s.name.toLowerCase() === 'about');
    const introImageUrl = introSection ? await getPostCoverImage(introSection.id) : null;

    const introContent = introSection ? contentMap['intro'] : null;
    const worksContent = worksSection ? contentMap['works'] : null;
    const aboutContent = aboutSection ? contentMap['about'] : null;

    const introParsed = parseMarkdown(introContent?.content || '');
    const mappedSocialLinks = socialEntries.map((entry) => ({
        url: entry.url,
        text: entry.title,
    }));
    const introSocialLinks =
        mappedSocialLinks.length > 0
            ? mappedSocialLinks
            : introParsed.links.filter((link) => Boolean(platformFromUrl(link.url)));
    const aboutParsed = parseMarkdown(aboutContent?.content || '');
    const aboutBlocks = parseAboutBlocks(aboutContent?.content || '');
    const introImage = introImageUrl || '/images/intro-bg.jpg';
    const introDescription = introParsed.paragraphs[0] || '';

    return (
        <>
            {sections.map((section) => {
                const sectionKey = section.name.toLowerCase();
                const sectionContent = contentMap[sectionKey];

                if (sectionKey === 'intro') {
                    return (
                        <section id="intro" className="s-intro target-section" key={section.id}>
                            <div className="row s-intro__content width-sixteen-col">
                                <div className="column lg-12 s-intro__content-inner grid-block grid-16">
                                    <div className="s-intro__content-text">
                                        <div className="s-intro__content-pretitle text-pretitle">
                                            {introParsed.pretitle}
                                        </div>
                                        <h1 className="s-intro__content-title">{introParsed.heading || section.title}</h1>

                                        <p className="s-intro__content-desc">{introDescription}</p>
                                    </div>
                                </div>
                            </div>

                            <ul className="s-intro__social social-list">
                                {introSocialLinks.map((link) => {
                                    const platform = platformFromUrl(link.url) || link.text.toLowerCase();

                                    return (
                                        <li key={link.url}>
                                            <a href={link.url} target={link.url === '#0' ? undefined : '_blank'} rel={link.url === '#0' ? undefined : 'noreferrer noopener'}>
                                                <SocialIcon platform={platform} />
                                                <span className="u-screen-reader-text">{link.text || platform}</span>
                                            </a>
                                        </li>
                                    );
                                })}
                            </ul>

                            <div className="s-intro__content-media">
                                <Image
                                    src={introImage}
                                    alt={introParsed.heading || 'Intro image'}
                                    fill
                                    priority
                                    sizes="(max-width: 1080px) 100vw, 50vw"
                                    style={{ objectFit: 'cover' }}
                                />
                            </div>

                            <div className="s-intro__scroll-down">
                                <a href="#about" className="smoothscroll">
                                    <div className="scroll-icon">
                                        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
                                            <path d="M11.178 19.569a.998.998 0 0 0 1.644 0l9-13A.999.999 0 0 0 21 5H3a1.002 1.002 0 0 0-.822 1.569l9 13z" />
                                        </svg>
                                    </div>
                                    <span className="scroll-text u-screen-reader-text">Scroll Down</span>
                                </a>
                            </div>
                        </section>
                    );
                }

                if (sectionKey === 'works') {
                    return (
                        <section id="works" className="s-works target-section" key={section.id}>
                            <div className="row">
                                <div className="column xl-12">
                                    {/*<div className="section-header" data-num="01">*/}
                                    <div className="section-header">
                                        <h1 className="text-display-title">
                                            {section.title || worksContent?.title || section.name}
                                        </h1>
                                    </div>
                                </div>
                            </div>

                            <BlogPosts />
                        </section>
                    );
                }

                if (sectionKey === 'about') {
                    return (
                        <section id="about" className="s-about target-section" key={section.id}>
                            <div className="row s-about__content">
                                <div className="column xl-12">
                                    {/*<div className="section-header" data-num="02">*/}
                                    <div className="section-header">
                                        <h1 className="text-display-title">{section.title || section.name}</h1>
                                    </div>

                                    {aboutParsed.paragraphs[0] ? (
                                        <p className="attention-getter">{aboutParsed.paragraphs[0]}</p>
                                    ) : null}

                                    <div className="grid-list-items s-about__blocks">
                                        {aboutBlocks.length > 0
                                            ? aboutBlocks.map((block, index) => (
                                                <div className="grid-list-items__item s-about__block" key={`${block.title}-${index}`}>
                                                    <h4 className="s-about__block-title">{block.title}</h4>

                                                    <ul className="s-about__list">
                                                        {block.items.map((item, itemIndex) => (
                                                            <li key={`${item}-${itemIndex}`}>{item}</li>
                                                        ))}

                                                        {block.textBlocks.map((textGroup, textGroupIndex) => {
                                                            const [primary, secondary, ...rest] = textGroup;

                                                            return (
                                                                <li key={`text-group-${block.title}-${textGroupIndex}`}>
                                                                    {primary}
                                                                    {secondary ? <span>{secondary}</span> : null}
                                                                    {rest.length > 0
                                                                        ? rest.map((line, lineIndex) => (
                                                                            <span key={`${line}-${lineIndex}`} style={{ display: 'block' }}>
                                                                                {line}
                                                                            </span>
                                                                        ))
                                                                        : null}
                                                                </li>
                                                            );
                                                        })}
                                                    </ul>
                                                </div>
                                            ))
                                            : aboutParsed.listItems.length > 0
                                                ? [
                                                    <div className="grid-list-items__item s-about__block" key="about-list-fallback">
                                                        <h4 className="s-about__block-title">Highlights</h4>
                                                        <ul className="s-about__list">
                                                            {aboutParsed.listItems.map((item, itemIndex) => (
                                                                <li key={`${item}-${itemIndex}`}>{item}</li>
                                                            ))}
                                                        </ul>
                                                    </div>,
                                                ]
                                                : null}
                                    </div>
                                </div>
                            </div>
                        </section>
                    );
                }

                if (sectionKey === 'contact') {
                    return null;
                }

                return (
                    <section id={sectionKey} className="target-section" key={section.id}>
                        <div className="section-header">
                            <h1 className="text-display-title">{section.title || section.name}</h1>
                        </div>
                        <div className="row">
                            <div className="column">
                                <Markdown content={sectionContent?.content || ''} />
                            </div>
                        </div>
                    </section>
                );
            })}
        </>
    );
}
