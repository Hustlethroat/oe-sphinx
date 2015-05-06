$(function() {
  // TODO: pull by ajax
  var dummyData = [
    {
      value: 'First label',
      title: 'First title',
      desc: 'Lorem ipsum dolor sit amet, consectetur adipisicing elit. Accusamus cum, quos, dolorum culpa iusto nulla assumenda, aliquam inventore accusantium illo incidunt neque maxime impedit dolores delectus at odio! Ipsum, quidem!'
    },
    {
      value: 'Second label',
      title: 'Second title',
      desc: 'Lorem ipsum dolor sit amet, consectetur adipisicing elit. Accusamus cum, quos, dolorum culpa iusto nulla assumenda, aliquam inventore accusantium illo incidunt neque maxime impedit dolores delectus at odio! Ipsum, quidem!'
    },
    {
      value: 'Third label',
      title: 'Third title',
      desc: 'Third Desc'
    },
    {
      value: 'Fourth label',
      title: 'Fourth title',
      desc: 'Fourth Desc'
    },
    {
      value: 'Fifth label',
      title: 'Fifth title',
      desc: 'Fifth Desc'
    }
  ];

  // wrap given query in string
  function wrapQuery (needle, haystack) {
    if (! needle || ! haystack)  {
      return haystack;
    }
    function replacer(match, offset, fullString) {
      mask = mask.substring(0, offset) + match.replace(/./g, '#') + mask.substring(offset + match.length);
      return match;
    }
    var re   = new RegExp('[^\\w\u0105\u010D\u0119\u0117\u012F\u0161\u0173\u016B\u017E\u0451\u0430-\u044F]', 'gi');
    var s    = haystack.toLowerCase().replace(re, ' ');
    var q    = needle.toLowerCase().replace(re, ' ').split(' ');
    var mask = s.replace(/./g, '+');
    var res  = '';

    for (var i in q) {
      if (q[i] === '' || s.indexOf(q[i]) === -1) {
        continue;
      }
      s.replace(new RegExp(q[i], 'g'), replacer);
    }

    mask = mask.replace(/#+/g, '<span class="list__emphasis">$&</span>');

    for (i = 0; i < mask.length; i ++) {
      if (mask.substr(i, 1) === '#' || mask.substr(i, 1) === '+') {
        res += haystack.substr(0,1);
        haystack = haystack.substr(1);
      } else {
        res += mask.substr(i, 1);
      }
    }
    return res;
  }

  // called when an item is selected
  function selectItem (event, ui) {
    $('[data-hook~=article-title]').html(ui.item.value);
    $('[data-hook~=article-body]').html(ui.item.desc);
  }

  // number of occurences
  function countWords (needles, haystack) {
    var words = needles.split(' ');
    var count = 0;
    var re;
    for (var i = 0; i < words.length; i++) {
      re = new RegExp(words[i], 'gi');
      count += (haystack.match(re) || []).length;
    }
    return count;
  }

  // shorten string to max chars
  function shorten (text, max) {
    if (! max || isNaN(max)) {
      max = 50;
    }
    if (text.length <= max) {
      return text;
    }
    return text.substring(0, max - 3) + '...';
  }

  var $input = $('[data-hook~=search-input]');

  // initialize autocomplete
  $input.autocomplete({
    minLength: 3,
    source: dummyData,
    select: selectItem,
    appendTo: '[data-hook~=search]'
  });

  // custom autocomplete list
  $input.data('ui-autocomplete')._renderItem = function (ul, item) {
    var count = 0;
    count += countWords(this.term, item.desc);
    count += countWords(this.term, item.value);
    return $('<li class="list__item">')
      .html(wrapQuery(this.term, shorten(item.desc, 150)))
      .prepend(
        $('<div class="list__item-header">' +
        wrapQuery(this.term, shorten(item.value, 50)) + '</div>')
        .prepend('<div class="list__item-count">' + count + '</div>')
      )
      .appendTo(ul);
  };

  // custom autocomplete menu
  $input.data('ui-autocomplete')._renderMenu = function(ul, items) {
    var that = this;
    ul.addClass("list");
    $.each(items, function(index, item) {
      that._renderItemData(ul, item);
    });
  };

});
