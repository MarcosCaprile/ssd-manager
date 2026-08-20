<?php

declare(strict_types=1);

namespace App\Services;

use App\Core\Response;

final class ObjectionableContentFilter
{
    /**
     * The filter deliberately focuses on unambiguous severe insults, sexual
     * content and direct threats. Less clear cases remain reportable so normal
     * school and first-aid vocabulary is not silently blocked.
     *
     * @var array<int,string>
     */
    private const BLOCKED_PATTERNS = [
        '/\b(?:arschloch|hurensohn|hurenkind|missgeburt|wichser|fotze)\b/u',
        '/\b(?:motherfucker|cunt|fuck(?:ing|er)?)\b/u',
        '/\b(?:porno?|pornografie|nacktbilder?)\b/u',
        '/\b(?:ich\s+toete\s+dich|bring\s+dich\s+um|kill\s+yourself|kys)\b/u',
    ];

    public static function assertAllowed(string $value): void
    {
        if (self::containsBlockedContent($value)) {
            Response::error(
                'Dieser Inhalt kann nicht gesendet werden. Bitte formuliere ihn respektvoll und ohne unangemessene Inhalte.',
                422
            );
        }
    }

    public static function containsBlockedContent(string $value): bool
    {
        $normalized = mb_strtolower($value);
        $normalized = strtr($normalized, [
            '@' => 'a',
            '0' => 'o',
            '1' => 'i',
            '3' => 'e',
            '4' => 'a',
            '5' => 's',
            '7' => 't',
            '$' => 's',
        ]);
        $normalized = strtr($normalized, ['ä' => 'ae', 'ö' => 'oe', 'ü' => 'ue', 'ß' => 'ss']);
        $normalized = preg_replace('/[^\p{L}\p{N}]+/u', ' ', $normalized) ?? '';
        $normalized = trim(preg_replace('/\s+/u', ' ', $normalized) ?? '');

        foreach (self::BLOCKED_PATTERNS as $pattern) {
            if (preg_match($pattern, $normalized) === 1) {
                return true;
            }
        }
        return false;
    }
}
