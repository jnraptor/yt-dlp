import functools
import re
import urllib.parse

from .common import InfoExtractor
from ..utils import (
    ExtractorError,
    OnDemandPagedList,
)


class TokyoMotionBaseIE(InfoExtractor):
    _COMMON_HEADERS = {
        'Accept-Encoding': '*',
    }

    def _extract_video_urls(self, webpage):
        return (
            'https://www.%smotion.net%s' % (self._VARIANT, urllib.parse.quote(frg.group()))
            for frg in re.finditer(r'/video/(?P<id>\d+)/[^#?&"\']+', webpage))

    def _fetch_page(self, user_id, index):
        index += 1
        url = self._PAGING_BASE_TEMPLATE % (user_id, index)
        webpage = self._download_webpage(
            url, user_id, headers=self._COMMON_HEADERS, note=f'Downloading page {index}')
        yield from [self.url_result(u) for u in self._extract_video_urls(webpage)][::2]


class _MotionVideoIE(TokyoMotionBaseIE):
    def _real_extract(self, url):
        mobj = self._match_valid_url(url)
        url, video_id, excess = mobj.group(0, 'id', 'excess')
        if not excess:
            # fix URL silently
            url = url.split('#')[0]
            if not url.endswith('/'):
                url += '/'
            url += 'a'

        webpage = self._download_webpage(url, video_id, headers=self._COMMON_HEADERS)
        title = self._og_search_title(webpage, default=None)

        entries = self._parse_html5_media_entries(url, webpage, video_id, m3u8_id='hls')
        if not entries:
            raise ExtractorError('This is a private video.', expected=True)
        entry = entries[0]

        for fmt in entry['formats']:
            fmt['preference'] = 1 if fmt.get('format_id') == 'HD' else -1

        entry.update({
            'id': video_id,
            'title': title,
            'age_limit': 18,
        })
        return entry


class _MotionPlaylistIE(TokyoMotionBaseIE):
    def _real_extract(self, url):
        user_id = self._match_id(url)
        entries = OnDemandPagedList(functools.partial(self._fetch_page, user_id), 18)
        return self.playlist_result(entries, user_id, self._TITLE_TEMPLATE % user_id)


class TokyoMotionIE(_MotionVideoIE):
    _VARIANT = 'tokyo'
    IE_NAME = 'tokyomotion'
    _VALID_URL = r'https?://(?:www\.)?tokyomotion\.net/video/(?P<id>\d+)(?P<excess>/[^#\?]+)?'
    _TESTS = [{
        'url': 'https://www.tokyomotion.net/video/12345/title',
        'only_matching': True,
    }, {
        'url': 'https://tokyomotion.net/video/12345/title',
        'only_matching': True,
    }]


class TokyoMotionUserIE(_MotionPlaylistIE):
    _VARIANT = 'tokyo'
    IE_NAME = 'tokyomotion:user'
    _VALID_URL = r'https?://(?:www\.)?tokyomotion\.net/user/(?P<id>[^/]+)(?:/videos)?$'
    _PAGING_BASE_TEMPLATE = 'https://www.tokyomotion.net/user/%s/videos?page=%d'
    _TITLE_TEMPLATE = 'Uploads from %s'
    _TESTS = [{
        'url': 'https://www.tokyomotion.net/user/SomeUser/videos',
        'only_matching': True,
    }, {
        'url': 'https://www.tokyomotion.net/user/SomeUser',
        'only_matching': True,
    }]


class TokyoMotionUserFavsIE(_MotionPlaylistIE):
    _VARIANT = 'tokyo'
    IE_NAME = 'tokyomotion:user:favs'
    _VALID_URL = r'https?://(?:www\.)?tokyomotion\.net/user/(?P<id>[^/]+)/favorite/videos'
    _PAGING_BASE_TEMPLATE = 'https://www.tokyomotion.net/user/%s/favorite/videos?page=%d'
    _TITLE_TEMPLATE = 'Favorites from %s'
    _TESTS = [{
        'url': 'https://www.tokyomotion.net/user/SomeUser/favorite/videos',
        'only_matching': True,
    }]


class TokyoMotionSearchesIE(_MotionPlaylistIE):
    _VARIANT = 'tokyo'
    IE_NAME = 'tokyomotion:searches'
    _VALID_URL = r'https?://(?:www\.)?tokyomotion\.net/search\?search_query=(?P<id>[^/&]+)(?:&search_type=videos)?(?:&page=\d+)?'
    _PAGING_BASE_TEMPLATE = 'https://www.tokyomotion.net/search?search_query=%s&search_type=videos&page=%d'
    _TITLE_TEMPLATE = 'Search results for %s'
    _TESTS = [{
        'url': 'https://www.tokyomotion.net/search?search_query=example&search_type=videos',
        'only_matching': True,
    }, {
        'url': 'https://www.tokyomotion.net/search?search_query=example',
        'only_matching': True,
    }]


class OsakaMotionIE(_MotionVideoIE):
    _VARIANT = 'osaka'
    IE_NAME = 'osakamotion'
    _VALID_URL = r'https?://(?:www\.)?osakamotion\.net/video/(?P<id>\d+)(?P<excess>/[^#\?]+)?'
    _TESTS = [{
        'url': 'https://www.osakamotion.net/video/12345/title',
        'only_matching': True,
    }, {
        'url': 'https://osakamotion.net/video/12345/title',
        'only_matching': True,
    }]


class OsakaMotionUserIE(_MotionPlaylistIE):
    _VARIANT = 'osaka'
    IE_NAME = 'osakamotion:user'
    _VALID_URL = r'https?://(?:www\.)?osakamotion\.net/user/(?P<id>[^/]+)(?:/videos)?$'
    _PAGING_BASE_TEMPLATE = 'https://www.osakamotion.net/user/%s/videos?page=%d'
    _TITLE_TEMPLATE = 'Uploads from %s'
    _TESTS = [{
        'url': 'https://www.osakamotion.net/user/SomeUser/videos',
        'only_matching': True,
    }, {
        'url': 'https://www.osakamotion.net/user/SomeUser',
        'only_matching': True,
    }]


class OsakaMotionUserFavsIE(_MotionPlaylistIE):
    _VARIANT = 'osaka'
    IE_NAME = 'osakamotion:user:favs'
    _VALID_URL = r'https?://(?:www\.)?osakamotion\.net/user/(?P<id>[^/]+)/favorite/videos'
    _PAGING_BASE_TEMPLATE = 'https://www.osakamotion.net/user/%s/favorite/videos?page=%d'
    _TITLE_TEMPLATE = 'Favorites from %s'
    _TESTS = [{
        'url': 'https://www.osakamotion.net/user/SomeUser/favorite/videos',
        'only_matching': True,
    }]


class OsakaMotionSearchesIE(_MotionPlaylistIE):
    _VARIANT = 'osaka'
    IE_NAME = 'osakamotion:searches'
    _VALID_URL = r'https?://(?:www\.)?osakamotion\.net/search\?search_query=(?P<id>[^/&]+)(?:&search_type=videos)?(?:&page=\d+)?'
    _PAGING_BASE_TEMPLATE = 'https://www.osakamotion.net/search?search_query=%s&search_type=videos&page=%d'
    _TITLE_TEMPLATE = 'Search results for %s'
    _TESTS = [{
        'url': 'https://www.osakamotion.net/search?search_query=example&search_type=videos',
        'only_matching': True,
    }, {
        'url': 'https://www.osakamotion.net/search?search_query=example',
        'only_matching': True,
    }]
