0.8.0

* Support for text-2.0 (#57)
* Support for ICU 69 and new features (#55)
* Add lib/include dirs for newer homebrew (#54)
* basic number formatting added (#46)
* Declare pkg-config dependencies (#43)
* Added support for arabic shaping and BiDi (#41)
* Include icuio lib (#36)
* Character Set Detection (#27)

0.7.1.0

* Add fix for undefined TRUE value in cbits (#52)
* Improve CI and documentation (#20)

Thanks to everyone who contributed!

0.7.0.0

* Built and tested against ICU 53.

* The isoComment function has been deprecated, and will be removed in
  the next major release.

* The Collator type is no longer an instance of Eq, as this
  functionality has been removed from ICU 53.

* Many NFData instances have been added.
