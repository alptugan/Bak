import { getBlogPosts, slugify } from '@/lib/notion';
import { baseUrl } from './layout';

export default async function sitemap() {
    const posts = await getBlogPosts();

    const works = posts.map((post) => ({
        url: `${baseUrl}/works/${slugify(post.title || post.name)}`,
        lastModified: post.date,
    }));

    const routes = [''].map((route) => ({
        url: `${baseUrl}${route}`,
        lastModified: new Date().toISOString().split('T')[0],
    }));

    return [...routes, ...works];
}
