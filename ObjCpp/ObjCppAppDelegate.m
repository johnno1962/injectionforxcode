//
//  ObjCppAppDelegate.m
//  ObjCpp
//
//  Created by John Holdsworth on 14/04/2009.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

// obj*.h implicitly included from ObjCpp_Prefix.pch

struct _objcpp_debug _objcpp = {NO, 0};

static struct {
	char actual[100*1024*1024];
	const char *aptr;
	int line;
} adata;


#ifdef OODEBUG
void OOVerify( NSString *fmt, ... ) NS_FORMAT_FUNCTION(1,2);
void OOVerify( NSString *fmt, ... ) {
	va_list argp;
	va_start(argp, fmt);
#if 0
#define OODEBUG_EXPECT
#endif
#ifdef OODEBUG_EXPECT
    NSString *log = [[NSString alloc] initWithFormat:fmt arguments:argp];
#else
    NSString *log = nil;
#endif
    OOAddress instance = va_arg( argp, OOAddress );
    const char *action = va_arg( argp, const char * );

    if ( log ) {
        NSLog( @"#%03d 0x%08lx %-10s - %@\n", adata.line, instance, 0&&action?action:"--", log );
        OO_RELEASE( log );
    }

	if ( adata.aptr ) {
		if ( strncmp( action, adata.aptr, strlen( action ) ) != 0 ) {
			NSLog( @"*** ACTION: %s, expected %s, line %d\n", action, adata.aptr, adata.line );
			if ( adata.actual[0] )
                strcat( adata.actual, " " );
			strcat( adata.actual, action );
		}
		else if ( *(adata.aptr += strlen( action )) )
            adata.aptr++;
	}
	va_end( argp );
}

#define OOExpect( _actions ) _OOExpect( _actions, __LINE__ )

#else

void OOVerify( NSString *fmt, ... ) {}
#define OOExpect( _actions ) (void)( _actions )

#endif


static void _OOExpect( const char *actions, int line ) {
	if ( adata.aptr && *adata.aptr )
		printf( "*** Remainder: %s, line %d\n", adata.aptr, adata.line );
	if ( adata.actual[0] ) {
		printf( "*** Unexpected: OOExpect( \"%s\" );, line %d\n", adata.actual, adata.line );
		adata.actual[0] = '\000';
	}
	adata.aptr = actions;
	adata.line = line;
}

/**
 A test class to check objects in C++ NSValue wrapper classes are recovered properly.
 */

static int _objcpp_contructed;

class OOClassTest {
public:
	OOClassTest() { _objcpp_contructed++; OOTrace( @"0x%08lx %s", (OOAddress)this, "TCONSTRUCT" ); }
	~OOClassTest() { _objcpp_contructed--; OOTrace( @"0x%08lx %s", (OOAddress)this, "TDESTRUCT" ); }
};

#import "ObjCppAppDelegate.h"

@implementation OOTestObjC

static int _objcpp_alloced;

- init {
	if ( self = [super init] ) {
		_objcpp_alloced++;
	}
    //NSLog( @"ALLOC" );
	return self;
}

- (void)dealloc {
	_objcpp_alloced--;
    //NSLog( @"DEALLOC" );
	OO_DEALLOC( super );
}

@end

@class ChildRecord;

@interface ParentRecord : OORecord {
@public
	OOString ID;
	char c;
	short s;
	int i;
	float f;
	double d;
}
- (OOArray<ChildRecord *>)children;
@end

@interface ChildRecord : OORecord {
@public
	OOString ID;
	OOStringArray strs;
}
@end

class Counted {
public:
    int c;
    void func() {
        c++;
    }
    ~Counted() {
        OOTrace( @"0x%08lx %s", (OOAddress)this, "DECOUNTED" );
    }
};

static int rcount, awoke;

@implementation ParentRecord

+ (NSString *)ooTableName { return @"PARENT_TABLE"; };
+ (NSString *)ooTableKey { return @"ID"; }

- init { rcount++; return [super init]; };
- (OOArray<ChildRecord *>)children {
	return [ChildRecord selectRecordsRelatedTo:self];
}
- (void)dealloc { rcount--; return OO_DEALLOC( super ); }

@end

@implementation ChildRecord

+ (NSString *)ooTableName { return @"CHILD_TABLE"; };

- init { rcount++; return [super init]; };
- (void)awakeFromDB { awoke++; }

- (OOReference<ParentRecord *>)parent {
	return *[ParentRecord selectRecordsRelatedTo:self][0];
}

- (void)dealloc { rcount--; return OO_DEALLOC( super ); }

@end

@interface iTunesItem : OORecord {
	OOString title, link, description, pubDate, encoded, category, 
	artist, artistLink, album, albumLink, albumPrice;
}
@end
@implementation iTunesItem
@end

/**
 These tests are used to validate objcpp.h for releases only. They are in need of a tidy up....
 ==============================================================================================
 */

#define OOAssertAlloced(  _n ) if( !memoryManaged ) assert( _objcpp_alloced == _n )
#define OOAssertRetained( _n ) if( !memoryManaged ) assert( _objcpp.retained == _n )
#define OOAssertBuffered( _n ) if( !memoryManaged ) assert( _objvec.buffered == _n )
#define OOAssertConstructed( _n ) if( !memoryManaged ) assert( _objcpp_contructed == _n )

@implementation ObjCppAppDelegate

- (void)loadRequest:(NSURLRequest *)request frame:(NSString *)frame {
    NSLog( @"[req retainCount]: %ld", (OOLong)OO_RETAINCOUNT( request ) );
    //lastRequest = request;
    [self performSelector:@selector(reqTest) withObject:nil afterDelay:1.];
}

- (void)reqTest {
    NSLog( @"[lastRequest retainCount]: %ld",(OOLong)OO_RETAINCOUNT( lastRequest ) );
    ~lastRequest;
}

#ifdef __OBJC_GC__
static BOOL allTests = TRUE, memoryManaged = YES, useNetwork = TRUE;
#else
static BOOL allTests = TRUE, memoryManaged = NO, useNetwork = TRUE;
#endif

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    static int threads;
    threads++;
#ifndef OO_ARC
    [[NSGarbageCollector defaultCollector] enable];
#endif

	NSLog( @"Starting tests[%d] %ld %ld %ld",
          threads, (OOLong)sizeof(int), (OOLong)sizeof(long), (OOLong)sizeof(void *)/*,
          [@"abcabc" stringByReplacingOccurrencesOfString:@"b(.)" withString:@"h$1$1"
                                               options:NSRegularExpressionSearch range:NSMakeRange(0,3)]*/ );

#if 1
	if ( allTests ) {
        NSLog( @"basic references" );

		OOTestObjC *obj = [[OOTestObjC alloc] init];
		OOAssertAlloced( 1 );

		OOExpect( "INIT RETAIN" );
		OOReference<OOTestObjC *> autoRef = obj;
		OOAssertRetained( 1 );
		OO_RELEASE( obj );
		OOAssertAlloced( 1 );

		OOExpect( "RETAIN" );
		ivarRef = autoRef;
		OOAssertRetained( 2 );

		OOExpect( "DESTRUCT RELEASE" );
	}
	OOAssertRetained( 1 );
	OOAssertAlloced( 1 );

	OOExpect( "INIT RETAIN DESTRUCT RELEASE DESTRUCT RELEASE" );
	~ivarRef;
	OOExpect( NULL );

	OOAssertRetained( 0 );
	OOAssertAlloced( 0 );

	if ( allTests ) {
        NSLog( @"array references" );

		{
			OOExpect( "INIT" );
			OOArray<OOTestObjC *> autoArray;

			for ( int i=0 ; i<100 ; i++ ) {
				OOTestObjC *obj = [[OOTestObjC alloc] init];

				if ( i==0 )	OOExpect("ALLOC RETAIN");
				autoArray[i%10] = obj;
				OO_RELEASE( obj );
			}
            //NSLog( @"HERE4 %p %p", _objcpp.retained, &_objcpp );
			OOAssertRetained( 1 );
			OOAssertAlloced( 10 );

			OOExpect( "RETAIN" );
			ivarArray = autoArray;
			OOAssertRetained( 2 );

			OOExpect( "DESTRUCT RELEASE" );
		}
		OOAssertRetained( 1 );
		{
			OOExpect( "INIT RETAIN" );
			OOArray<OOTestObjC *> autoArray = ivarArray;
			OOAssertRetained( 2 );
			OOAssertAlloced( 10 );

			OOExpect( "DESTRUCT RELEASE" );
		}
	}
	OOAssertRetained( 1 );
	OOAssertAlloced( 10 );

	OOExpect( "RELEASE" );
	ivarArray = nil;
	OOAssertRetained( 0 );
	OOAssertAlloced( 0 );
    
	if ( allTests ) {
        NSLog( @"dictionary references" );

		{
			OOExpect( "INIT" );
			OODictionary<OOTestObjC *> autoDict;
			for ( int i=0 ; i<10 ; i++ ) {
				OOTestObjC *obj = [[OOTestObjC alloc] init];
				OOExpect( i==0 ?
                        "INIT RETAIN ALLOC RETAIN DESTRUCT RELEASE" :
                        "INIT RETAIN DESTRUCT RELEASE" );
                //OO_RELEASE( obj->ref = [[OOTestObjC alloc] init] );
				autoDict[[NSString stringWithFormat:@"K%d", i]] = obj;
				OO_RELEASE( obj );
			}
			OOAssertRetained( 1 );
			OOAssertAlloced( 10 );

			OOExpect("INIT RETAIN");
			OODictionary<OOTestObjC *> autoDict2 = autoDict;
			OOAssertRetained( 2 );
			OOAssertAlloced( 10 );

			OOExpect("RETAIN");
			ivarDict = autoDict2;

			OOExpect("DESTRUCT RELEASE DESTRUCT RELEASE");
		}
	}
	OOAssertRetained( 1 );
	OOAssertAlloced( 10 );

	OOExpect( "INIT RETAIN DESTRUCT RELEASE DESTRUCT RELEASE" );
	~ivarDict;
	OOAssertRetained( 0 );
	OOAssertAlloced( 0 );

	if ( allTests ) {
        NSLog( @"mixed subscripts" );

		OOExpect( "INIT" );
		OODictionary<OOTestObjC *> autoMixed;
		for ( int i=0 ; i<10 ; i++ ) {
			OOTestObjC *obj = [[OOTestObjC alloc] init];
			OOExpect( i==0 ?
                     "INIT RETAIN VIVIFY VIVIFY ALLOC RETAIN DESTRUCT RELEASE " :
                     "INIT RETAIN VIVIFY VIVIFY DESTRUCT RELEASE " );
			autoMixed[[NSString stringWithFormat:@"K%d", i]][i][i] = obj;
			OO_RELEASE( obj );
		}
		OOExpect("DESTRUCT RELEASE");
		///OOPrint( autoMixed );
	}
	OOAssertRetained( 0 );
	OOAssertAlloced( 0 );

    if(1) {
        OOExpect( NULL );
        _objcpp.trace = 1;
        NSString *s = @"kjkhj";
        
        OOStringDict dict;
        for ( int i=0 ; i<100 ; i++ ) {
            OOString k = @"K";
            k+=i;
            dict[OO"K"+i] = s;
        }
        
        OOStringArray stringArray;
		for ( int i=0 ; i<100 ; i++ )
			stringArray[i/10] = s;
        ~stringArray;
		for ( int i=0 ; i<100 ; i++ )
			stringArray[i/10][i/10] = s;
        ~stringArray;
		for ( int i=0 ; i<100 ; i++ )
			stringArray[i/10][OO"K"+i][i] = s;
        
        OOString oos = @"123";
		for ( int i=0 ; i<100 ; i++ )
			stringArray[0] = oos;
    }
    
	if ( allTests ) {
        NSLog( @"string class" );

		OOExpect("INIT");
		OOString str;

		OOExpect("ALLOC RETAIN");
		str += @"Hello World";

		OOExpect("INIT COPY RETAIN INIT RETAIN DESTRUCT RELEASE INIT COPY RETAIN INIT RETAIN DESTRUCT RELEASE "
				 "INIT RETAIN INIT COPY RETAIN INIT RETAIN DESTRUCT RELEASE DESTRUCT RELEASE INIT COPY RETAIN INIT RETAIN "
				 "DESTRUCT RELEASE RETAIN RELEASE DESTRUCT RELEASE DESTRUCT RELEASE DESTRUCT RELEASE DESTRUCT RELEASE" );
		str = str+@" and "+99.5+" "+123;

		OOExpect("INIT RETAIN DESTRUCT RELEASE");
		str += "!";

		OOExpect("INIT COPY RETAIN INIT COPY RETAIN");
		OOString str2 = @"Not correct", str3 = @"Hello World and 99.500000 123!";

		assert( str != str2 );
		assert( str == str3 );
		assert( str2 > str3 );
		assert( str >= str3 );
		OOAssertRetained( 3 );

		OOExpect("RETAIN");
		ivarString = str;

		OOExpect("DESTRUCT RELEASE DESTRUCT RELEASE DESTRUCT RELEASE");
	}
	OOAssertRetained( 1 );
	OOExpect("RELEASE");
	ivarString = nil;
	OOAssertRetained( 0 );

	if ( allTests ) {
        NSLog( @"vectors" );

		{
			OOExpect( "INIT" );
			OOVector<double> autoVector;

			OOExpect( "CALLOC BCONSTRUCT RETAIN BREALLOC BREALLOC BREALLOC BREALLOC BREALLOC" );
			for ( int i=0 ; i<100 ; i++ )
				autoVector[i] = i*99.;
			OOAssertRetained( 1 );

			for ( int i=0 ; i<100 ; i++ )
				assert( autoVector[i] == i*99. );

			OOExpect( "RETAIN" );
			ivarVector = autoVector;
			OOAssertRetained( 2 );

			OOExpect( "RELEASE DESTRUCT" );
		}
		OOAssertBuffered( 1 );
		for ( int i=0 ; i<100 ; i++ )
			assert( ivarVector[i] == i*99. );

		// 2-d matrix
		OOExpect( "INIT" );
		OOMatrix<int> mx;

		OOExpect( "CALLOC BCONSTRUCT RETAIN "
				 "BCONSTRUCT BCONSTRUCT BCONSTRUCT BCONSTRUCT BCONSTRUCT BCONSTRUCT BCONSTRUCT BCONSTRUCT "
				 "BCONSTRUCT BCONSTRUCT BCONSTRUCT BCONSTRUCT BCONSTRUCT BCONSTRUCT BCONSTRUCT BCONSTRUCT "
				 "BREALLOC BREALLOC" );
		mx[1][1000] = 99;
		assert( mx[1][1000] == 99. );

		OOExpect( "CDESTROY BDESTRUCT BDESTRUCT DESTRUCT RELEASE DESTRUCT" );
	}
	OOAssertRetained( 1 );

	OOExpect( "INIT RETAIN RELEASE CDESTROY BDESTRUCT DESTRUCT RELEASE DESTRUCT" );
	~ivarVector;

	OOAssertBuffered( 0 );
	OOAssertRetained( 0 );

	if ( allTests ) {
        NSLog( @"vector hash" );

		OOExpect( "INIT" );
		OOClassDict<OOVector<double> > classDict;
#ifdef __clang__
		OOExpect( "INIT RETAIN INIT BREALLOC BCONSTRUCT RETAIN INIT RETAIN INIT ALLOC RETAIN DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE" );
#else
		OOExpect( "INIT BREALLOC BCONSTRUCT RETAIN INIT RETAIN INIT RETAIN INIT ALLOC RETAIN DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE" );
#endif
		classDict[@"ONE"] = new OOVector<double>(100);

#ifdef __clang__
		OOExpect( "INIT RETAIN INIT INIT RETAIN INIT DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE" );
#else
		OOExpect( "INIT INIT RETAIN INIT RETAIN INIT DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE" );
#endif
		classDict[@"TWO"] = new OOVector<double>;

		OOExpect( "INIT RETAIN INIT RETAIN INIT RETAIN RELEASE DESTRUCT DESTRUCT RELEASE" );
		OOVector<double> vector = **classDict[@"ONE"];
		vector[99] = 43;
		vector[99]++;

		OOExpect( "INIT RETAIN INIT RETAIN DESTRUCT RELEASE INIT RETAIN RELEASE DESTRUCT DESTRUCT RELEASE" );
		assert( (**classDict["ONE"])[99] == 44 );
		OOAssertBuffered( 1 );

#ifdef OO_ARC
        OOExpect( "INIT RETAIN INIT RETAIN DESTRUCT RELEASE INIT RETAIN INIT RETAIN RELEASE DESTRUCT CDESTROY "
                 "RELEASE DESTRUCT DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE INIT RETAIN INIT RETAIN DESTRUCT RELEASE "
                 "INIT RETAIN INIT RETAIN RELEASE DESTRUCT CDESTROY DESTRUCT DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE "
                 "CDESTROY BDESTRUCT DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE DESTRUCT" );
        ~classDict["ONE"];
        ~classDict["TWO"];
#else
        OOExpect( "RELEASE DESTRUCT INIT COPY RETAIN INIT RETAIN INIT RETAIN INIT RETAIN RELEASE DESTRUCT CDESTROY CDESTROY BDESTRUCT "
				 "DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE INIT RETAIN INIT RETAIN INIT RETAIN RELEASE DESTRUCT CDESTROY "
				 "DESTRUCT DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE DESTRUCT RELEASE RELEASE DESTRUCT" );
#endif
	}
	OOAssertBuffered( 0 );
	OOAssertRetained( 0 );

	if ( allTests ) {
        NSLog( @"vector array" );

		OOExpect( "INIT" );
		OOClassArray<OOVector<double> > classArray;

		OOExpect( "INIT BREALLOC BCONSTRUCT RETAIN INIT RETAIN INIT ALLOC RETAIN DESTRUCT RELEASE DESTRUCT" );
		classArray[1] = new OOVector<double>(100);

		OOExpect( "INIT INIT RETAIN INIT DESTRUCT RELEASE DESTRUCT" );
		classArray[2] = new OOVector<double>();

		OOExpect( "INIT RETAIN CALLOC BCONSTRUCT RETAIN BREALLOC RELEASE DESTRUCT" );
		(**classArray[2])[0] = 0;

		OOExpect( "INIT RETAIN INIT RETAIN RELEASE DESTRUCT" );
		OOVector<double> vector = **classArray[2];

		OOExpect( "BREALLOC" );
		vector[99] = 43;

		OOExpect( "INIT RETAIN RELEASE DESTRUCT" );
		assert( (**classArray[2])[99] == 43 );
		OOAssertBuffered( 2 );

#ifdef OO_ARC
        OOExpect( "INIT RETAIN INIT RETAIN RELEASE DESTRUCT CDESTROY RELEASE DESTRUCT DESTRUCT RELEASE DESTRUCT "
                 "INIT RETAIN INIT RETAIN RELEASE DESTRUCT CDESTROY CDESTROY BDESTRUCT DESTRUCT RELEASE DESTRUCT "
                 "DESTRUCT RELEASE DESTRUCT CDESTROY BDESTRUCT DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE DESTRUCT" );
        ~classArray[2];
        ~classArray[1];
#else
        OOExpect( "RELEASE DESTRUCT INIT RETAIN INIT RETAIN RELEASE DESTRUCT CDESTROY CDESTROY BDESTRUCT DESTRUCT RELEASE "
				 "DESTRUCT DESTRUCT RELEASE DESTRUCT INIT RETAIN INIT RETAIN RELEASE DESTRUCT CDESTROY CDESTROY BDESTRUCT DESTRUCT "
				 "RELEASE DESTRUCT DESTRUCT RELEASE DESTRUCT INIT INIT DESTRUCT DESTRUCT RELEASE DESTRUCT" );
#endif
	}
	OOAssertBuffered( 0 );
	OOAssertRetained( 0 );

	if ( allTests ) {
        NSLog( @"object lists" );

		OOExpect( "INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT "
				 "INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT "
				 "INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT "
				 "INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT "
				 "INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT "
				 "INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT "
				 "INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT BREALLOC BCONSTRUCT RETAIN" );
		OOObjects<OOTestObjC *> autoObjects(100);

		for ( int i=0 ; i<10 ; i++ ) {
			OOTestObjC *obj = [[OOTestObjC alloc] init];
			OOExpect( "RETAIN" );
			autoObjects[i*10] = obj;
			OO_RELEASE( obj );
		}
		OOAssertAlloced( 10 );

		OOExpect( "CDESTROY BDESTRUCT "
				 "DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT RELEASE "
				 "DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT RELEASE "
				 "DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT RELEASE "
				 "DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT RELEASE "
				 "DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT RELEASE "
				 "DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT RELEASE "
				 "DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT RELEASE "
				 "DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT RELEASE "
				 "DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT RELEASE "
				 "DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT DESTRUCT RELEASE "
				 "DESTRUCT RELEASE DESTRUCT" );
	}
	OOAssertRetained( 0 );
	OOAssertAlloced( 0 );

#ifndef OO_ARC
	if ( allTests ) {
        NSLog( @"C++ class instance hash" );
    
		OOExpect( "INIT" );
		OOClassDict<OOClassTest> classDict;
		for ( int i=0 ; i<10 ; i++ ) {
            if ( i==0 )
#ifdef __clang__
                OOExpect( "INIT RETAIN TCONSTRUCT INIT RETAIN INIT ALLOC RETAIN DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE" );
#else
                OOExpect( "TCONSTRUCT INIT RETAIN INIT RETAIN INIT ALLOC RETAIN DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE" );
#endif
            else
#ifdef __clang__
                OOExpect( "INIT RETAIN TCONSTRUCT INIT RETAIN INIT DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE" );
#else
                OOExpect( "TCONSTRUCT INIT RETAIN INIT RETAIN INIT DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE" );
#endif
			classDict[[NSString stringWithFormat:@"K%d", i]] = new OOClassTest();
		}
		OOAssertConstructed( 10 );

		OOExpect( "RETAIN" );
		ivarClassDict = classDict;
		OOExpect( "RELEASE DESTRUCT" );
	}
	OOAssertConstructed( 10 );

	OOExpect( "INIT RETAIN RELEASE INIT COPY RETAIN "
			 "INIT RETAIN INIT RETAIN INIT RETAIN RELEASE DESTRUCT CDESTROY TDESTRUCT DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE "
			 "INIT RETAIN INIT RETAIN INIT RETAIN RELEASE DESTRUCT CDESTROY TDESTRUCT DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE "
			 "INIT RETAIN INIT RETAIN INIT RETAIN RELEASE DESTRUCT CDESTROY TDESTRUCT DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE "
			 "INIT RETAIN INIT RETAIN INIT RETAIN RELEASE DESTRUCT CDESTROY TDESTRUCT DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE "
			 "INIT RETAIN INIT RETAIN INIT RETAIN RELEASE DESTRUCT CDESTROY TDESTRUCT DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE "
			 "INIT RETAIN INIT RETAIN INIT RETAIN RELEASE DESTRUCT CDESTROY TDESTRUCT DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE "
			 "INIT RETAIN INIT RETAIN INIT RETAIN RELEASE DESTRUCT CDESTROY TDESTRUCT DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE "
			 "INIT RETAIN INIT RETAIN INIT RETAIN RELEASE DESTRUCT CDESTROY TDESTRUCT DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE "
			 "INIT RETAIN INIT RETAIN INIT RETAIN RELEASE DESTRUCT CDESTROY TDESTRUCT DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE "
			 "INIT RETAIN INIT RETAIN INIT RETAIN RELEASE DESTRUCT CDESTROY TDESTRUCT DESTRUCT RELEASE DESTRUCT DESTRUCT RELEASE "
			 "DESTRUCT RELEASE RELEASE DESTRUCT" );
	~ivarClassDict;
	OOAssertConstructed( 0 );
#endif

    if (1)  {
        OOCounted<Counted> a = new Counted();
        a = a;
        OOCounted<Counted> b = a, c;
        c = a;
        a->func();
        (*a).c++;
        a->c++;
        assert( a->c == 3 );
        OOExpect("DECOUNTED");
    }

	OOExpect(NULL);

#if 0001
	if ( allTests ) {
		OOStrings s( 100 );
		for ( int i=0 ; i<10 ; i++ )
			s += "str";
		assert( (int)s == 10 );
	}
#endif

	if ( 0 ) {
        NSLog( @"testing Catcher.m" );
		OOArray<NSString *> t;
		[t.alloc() objectAtIndex:1000];
	}

	if ( allTests ) {
        NSLog( @"string dictionary" );
    
		OOStringDict stringDict;
		for ( int i=0 ; i<10 ; i++ )
			stringDict[[NSString stringWithFormat:@"K%d", i]][i][i] = @"Hello";
		for ( int i=0 ; i<10 ; i++ )
			stringDict[[NSString stringWithFormat:@"K%d", i]][i][i] += " World";
		for ( int i=0 ; i<10 ; i++ )
			*stringDict[[NSString stringWithFormat:@"K%d", i]][i][i] += @"!";
		for ( int i=0 ; i<10 ; i++ )
			*stringDict[[NSString stringWithFormat:@"K%d", i]][i][i] += i;

		assert( stringDict["K0"][0][0] == @"Hello World!0" );
		assert( stringDict["K9"][9][9] == @"Hello World!9" );
		OOString str = @"Hello World!";
		for ( int i=0 ; i<10 ; i++ )
			assert( (*stringDict[[NSString stringWithFormat:@"K%d", i]][i][i] == str+i) );

		*stringDict["empty2"] += @"vivifys?";
		assert( !*stringDict["empty2"] );
		stringDict["empty1"] += @"vivifys?";
		OOString s2 = *stringDict["empty1"];
		////assert( stringDict["empty1"] == @"vivifys?" );
		stringDict["empty0"]["123"][99]["d"] += @"vivifys?";
		////assert( stringDict["empty0"]["123"][99]["d"] == "vivifys?" );
	}
	OOAssertRetained( 0 );

	if ( allTests ) {
        NSLog( @"string operators1" );

		OOString str;
		str <<= @"Hello World";
		assert( str[1] == 'e' );
		str[1] = 'a';
		assert( str[1] != 'e' );
        str / @"o";
        OOPattern(@"o");
        str & @"o";
		str[@"o"] = @"aa";

		OOString str2 = @"Hallaa Waarld";
		assert( str == str2 );
		OOString l = @"l";
        str - l;
		str <<= str - l;
		NSString *s = *l;
		str <<= str - s;
		str <<= str - "l";
		str += ";;";
		str2 = @"Haaa Waard;;";
		assert( str == str2 );
		str <<= @"";
		OOStringArray a(0);
		assert( !a );
		OOStringArray b(nil);
		assert( !b );
		OOStringArray c(OONil);
		assert( !c );
		assert( (int)a==0 );

		OOArray<NSString *> stringArray;
		stringArray[0] = @"ONE";
		stringArray[1] = @"TWO";

		OODictionary<NSString *> stringDict;
		stringDict[@"KEY1"] = @"STRING1";
		stringDict[@"KEY2"][@"SUBKEY1"] = @"STRING2";
		str <<= @"Hello World";
		if ( str[1] == 'e' )
			str[1] = 'a';
		str = str + @"!";
		str += @"!";
		if ( str != (OOString)@"Hallo World!!" )
			assert(0);
	}

	if ( allTests ) {
        NSLog( @"array operators" );

		OOString str = @"A C B";
		NSMutableString *s2 = str;
		NSString *s1 = str;
        [str length];
		OOStringArray a1 = (const char *)str, a2 = "C B A";
		assert( a1 != a2 );
		// reverse sort
		a1 = -+a1;
		assert( a1 == a2 );
		~a1[1];
		assert( a1 != a2 );
		~a2[-2];
		assert( a1 == a2 );
		OOArray<OOString> a3 = a2;
		assert( a1 == a3 );
		NSArray *a = a2;
		NSMutableArray *m = a2;
		assert( a1 == a );
		assert( a1 == m );
		assert( (int)a1 == 2 );
		a1 += a;
		assert( (int)a1 == 4 );
		a1 += m;
		assert( (int)a1 == 6 );
		a1 += str;
		assert( (int)a1 == 7 );
		a1 += s1;
		assert( (int)a1 == 8 );
		a1 += s2;
		assert( (int)a1 == 9 );
		a1 += "1 2 3";
		assert( (int)a1 == 10 );
		a1 -= a2;
		~a1[str];
		assert( (int)a1 == 3 );
		a1 -= s1;
		assert( (int)a1 == 1 );
		a1 = a;
		a1 = m;
	}

	if ( allTests ) {
        NSLog( @"set operators" );

		OOStringArray a1 = "A B C", a2 = "C D E", a3 = "C", a4 = "A B C D E", a5 = kCFNull;
		assert( (a1 & a2) == a3 );
		assert( (a1 | a2) == a4 );
		a1 -= 1;
		a1 -= OOString(@"A");
		assert( a1 == OOStrArray( "C" ) );
		OOStringDict aa = OONil;
		assert( !aa );
		OOStringArray bb = nil;
		assert( !bb );
#ifndef OO_ARC
		OOObjects<NSObject *> m, n=m;
#endif
		OOStrings p, q=p;

		OOStringDict a = "a 1 b 2", b = "b 3 c 4";
		assert( +OOStringArray( a & b ) == "2 b" );
		assert( +OOStringArray( a | b ) == "1 2 4 a b c" );
		assert( +OOStringArray( b | a ) == "1 3 4 a b c" );
    
        assert( (int)a4[(OOString)"A"] == 0 );
        assert( (int)a4[(OOString)"C"] == 2 );
        assert( (NSUInteger)a4[(OOString)@"F"] == NSNotFound );    
	}

	if ( allTests ) {
        NSLog( @"array merge" );

		OOStringArray a1 = "A B C", a2 = "D E", a3 = a1;
		a3 = a2;
		a1 += a2;
		assert( a1 == OOStrArray( "A B C D E" ) );
		assert( a1+a1 == OOStrArray( "A B C D E" )*2 );
		if ( 0 ) {
			NSString *s = nil;
			NSMutableString *m = nil;
			NSArray *aa = nil;
			NSMutableArray *ma = nil;
			OOString os, o1 = s, o2 = m, o3 = os;
			OOStringArray oa, sa1 = aa, sa2 = ma, sa3 = oa;
			os = nil; os = s; os = m;
			aa = nil; oa = aa; oa = ma; 
			OOArray<OOString> as, s1 = aa, s2 = ma, s3 = aa, s4 = as;
			OODictionary<OOString> ds;
			as = nil;
			ds = nil;
		}
	}

	if ( allTests ) {
        NSLog( @"type conversion" );

		NSMutableArray *in = [NSMutableArray arrayWithObjects:@"1", @"2", @"3", nil];
		OOStringArray arr = in;
		NSMutableArray *ref = arr;
		assert( ref == in );
		ref = *arr;
		assert( ref == in );
		if(0) assert( OO_RETAINCOUNT( ref ) == 2 );
		ref = &~arr; // [[*arr retain] autorelease]; //
		assert( ref == in );
		if(0) assert( OO_RETAINCOUNT( ref ) == 2 );

        OODict<NSString *> a;
        a[@"a"] = *OO"a";
        ~a[@"a"];
        ~a;
	}

	if ( allTests ) {
        NSLog( @"string operators" );

		OOString str;
		str <<= @"Hello World";
		if ( str[1] == 'e' )
			str[1] = 'a';
		str = str + @"!";
		str += @"!";
		assert( str == (OOString)@"Hallo World!!" );

		OODictionary<OOString> stringDict;
		for ( int i=0 ; i<10 ; i++ ) {
			stringDict[@"KEY"][i] <<= @"";
			stringDict[@"KEY"][i] += "Hello ";
			stringDict[@"KEY"][i] += "World!";
		}

		assert( str == str );
		assert( !(str != str) );
		if ( str == (OOString)@"Hallo World!!" )
			assert( 1 );
		if ( str != (OOString)@"Hallo World!!" )
			assert( 0 );

		NSString *s = @"Hi";
		NSMutableString *m = (NSMutableString *)@"Ho";
		if ( 0 ) {
			assert( str == s );
			assert( str != s );
			assert( str < s );
			assert( str > s );
			assert( str <= s );
			assert( str >= s );

			assert( str == m );
			assert( str != m );
			assert( str < m );
			assert( str > m );
			assert( str <= m );
			assert( str >= m );
		}

		str = s;
		str = m;
		if(0) OOAssertRetained( 2 );

		str = str + str;
		str = str + s;
		//str = str + m;
		str = str + 1;
		str = str + 1.;

		str += str;
		str += s;
		str += m;
		str += 1;
		str += 1.;
	}

	if ( allTests ) {
        NSLog( @"slice assign" );

		OOStringDict d = "a 1 b 2 c 3";
		d[OOSlice("c d e")] = OOSlice( "4 5 6" );
		assert( d[OOSlice("b c d")] == OOStringArray( "2 4 5" ) );
		assert( ~d[OOSlice("a b")] == OOStringArray( "1 2" ) );
		d[OOSlice("c d e")] = d[OOSlice("a b c")];
        assert( d[OOSlice("e")] == OOStringArray("4") );

		OOStringArray a = "1 2 3 4";
		a[NSMakeRange(0,2)] = OOStringArray( "5 6" );
		assert( a[NSMakeRange(1,2)] == OOStringArray( "6 3" ) );
		assert( ~a[NSMakeRange(2,2)] == OOStringArray( "3 4" ) );
		assert( a == OOStringArray( "5 6" ) );
        a += @"7";
		a[NSMakeRange(0,2)] = a[NSMakeRange(1,2)];
		assert( a == OOStringArray( "6 7 7" ) );
        a[NSMakeRange(0,2)] = d[OOSlice("e")];
		assert( a == OOStringArray( "4 7" ) );

		OOStringDict e;
		e[@"0"] = OOStringArray("1 2 3");
		OOStringArray f = e["0"];
		assert( f == "1 2 3" );
		assert( (int)f == 3 );
		assert( OOStringArray(e["0"]) == "1 2 3" );
	}

	if ( allTests ) {
        NSLog( @"string dictionary" );

		// string ops
		OOString str;
		str = "Hello";
		str += @" ";
		str = str + @"World";
		str += "!";

		str[NSMakeRange(0,5)] = @"Mellow";
		str[@"ll"] = @"";

		// dictionary access
		OOStringDict dict;
		dict[@"key1"] = str;
		dict[@"key1"] += @"!";
		*dict[@"key1"] += @"!";
		assert( dict[@"key1"] == OOString(@"Meow World!!!") );
		NSString *s = &dict["key1"];
		assert( dict["key1"] == s );

		// recurive data structures
		dict["key2"][0] = "A0";
		dict["key2"][1] = OOString(@"A1"); ////
		assert( OOStringArray(dict["key2"]) == OOStrArray( "A0 A1" ) );
		//NSLog( @"%@", *dict );

		OOString n(99.5);
		int i = n;
		assert( i==99 );

		if ( 1 ) {
			OOStringArray a2( dict["key2"] );
			NSArray *a = a2;
			NSMutableArray *n = a2;
			dict -= a2;
			dict -= a;
			dict -= n;
		}
		if ( 1 ) {
			//dict["a"]["b"] <<= @"1";
			dict["a"]["b"] = "1";
			dict["a"]["c"] = OOString(@"1");////
			OOStringDict d2 = dict["a"], d3 = "a 1 b 2";
			NSDictionary *d = d3;
			NSMutableDictionary *m = d3;
			assert( dict == dict );
			if (0) {
				assert( dict == d );
				assert( dict == m );
			}
			///dict += d;
			///dict += m;
			dict = m;
			dict = d;
		}
	}

	if ( allTests ) {
        NSLog( @"assignment" );

		NSMutableDictionary *d = nil;
		NSMutableArray *r = nil;
		OOArray<id> a;
		OODictionary<id> b = a, f = d;
		OOArray<id> c = b, e = a, g = r;
		a = *b;
		b = *a;

		// messaging boxed objects
		OOString s = 99.5;
		assert( [a count] == 0 );
		assert( [*s doubleValue] == 99.5 );
		assert( [s doubleValue] == 99.5 );

		OOArray<NSString *> x = "99.5";
		assert( [x[0] doubleValue] == 99.5 );
		//assert( [*x[0] doubleValue] == 99.5 );

		OOArray<OOString> y = "99.5";
		// compiler not this clever...
		//assert( [y[0] doubleValue] == 99.5 );
		assert( [*y[0] doubleValue] == 99.5 );
		assert( [**y[0] doubleValue] == 99.5 );

		// does give warning on compile
		//if ( 0 ) [*x[0] count];
		//if ( 0 ) [**y[0] count];

		// compiles but should give warning
#ifndef __clang__
		if ( 0 ) {
			[a doubleValue];
			[s count];
			[x[0] count];
			[*y[0] count];
		}
#endif
	}

	if ( allTests ) {
        NSLog( @"string array" );

		OOStringArray a = "1 2 3";
		NSMutableString *m = OO_AUTORELEASE( [@"1" mutableCopy] );
		NSString *s = m;
		OOString o = m;
		assert( a[0] == "1" );
		//assert( *a[0] == @"1" );
		assert( a[0] == s );
		assert( a[0] == m );
		assert( a[0] == o ); 
		o = s = m = (NSMutableString *)@"2";
		assert( a[0] != "2" );
		assert( a[0] != s );
		assert( a[0] != m );
		assert( a[0] != o );
		assert( a[0] < "2" );
		assert( a[0] < s );
		assert( a[0] < m );
		assert( a[0] < o );
		o = s;
		o = m;
		o = a[0];
		a[3][0] = "ok";
		o = a[-1][-1];
		assert( o=="ok" );
	}

	if( allTests ) {
		OOString a = "a", b = @"b", c = a;
		a = "a";
		a = @"a";
		a = c;
	}

	if( allTests ) {
        NSLog( @"append" );

		OOStringArray a = "1 2 3";
		a += a;
		a += *a;
		a += "5";
		assert( a == OOStrArray( "1 2 3 1 2 3 1 2 3 1 2 3 5" ) );
	}
#endif

	NSLog( @"slices" );
	if ( allTests ) {
		OOStringArray z;
		z[0][0] = OOStrArray( "1 2 3" );

		assert( [**z[0][0][0] isEqualTo:@"1"] );
		assert( z[0][0][0] == @"1" );
		assert( z[0][0][NSMakeRange(1,2)] == OOStrArray( "2 3" ) );

		OOStringDict d( "a 1 b 2 c 3" );
		OOSlice a( "a b c" );
		OOStringArray n( "1 2 3" ), r = *d[a];
		r = d[a];
		assert( r == n );
		assert( d[a] == n );
	}

	if ( allTests ) {
        NSLog( @"manual dictionary" );

		NSMutableString *str;
		str = OO_AUTORELEASE( [@"Hello" mutableCopy] );
		[str appendString:@" "];
		str = OO_AUTORELEASE( [[str stringByAppendingString:@"World"] mutableCopy] );
		[str appendString:@"!"];

		// dictionary access
		NSMutableDictionary *dict = [NSMutableDictionary dictionary];
		[dict setObject:str forKey:@"key1"];
		[dict setObject:OO_AUTORELEASE( [[[dict objectForKey:@"key1"] stringByAppendingString:@"!"] mutableCopy] ) forKey:@"key1"];
		[[dict objectForKey:@"key1"] appendString:@"!"];

		// recursive data structures
		if ( [dict objectForKey:@"key2"] == nil )
			[dict setObject:[NSMutableArray array] forKey:@"key2"];
		[[dict objectForKey:@"key2"] insertObject:@"A0" atIndex:0];
		[[dict objectForKey:@"key2"] insertObject:@"A1" atIndex:1];
		//NSLog( @"%@", dict );
	}

	if ( allTests ) {
        NSLog( @"substrings" );

		OOString x, y = OONil, yy = @"123";
		assert( !y );
		OOStrs xs = "1 2 3";
		x += 1;
		x += 1.;
		x += "x";
		x += @"y";
		x -= "y";
		x -= @"x";
		x += self;
		x += xs[0];
		//x -= xs[0];
		x = xs[0];
		assert( OOStr("abc")-"b" == "ac" );
		assert( OOStr("abc")+5 == "abc5" );
		assert( OOStr("ab44c")-"4" == "abc" );
		OOStringArray z( "a b c" );
		OOString s = z;
		s -= " ";
		assert( s=="abc" );
		s[1] = 'd';
		assert( s[0] == 'a' );
		assert( s=="adc" );
		s[OORange(2,3)] = "ddd";
		assert( s=="adddd" );
		s[OORange(1,5)] = @"";
		assert( s=="a" );
		NSString *a = @"";
		NSMutableString *b = OO_AUTORELEASE( [@"" mutableCopy] );
		s <<= @"";
		s += "";
		s = a;
		s += "";
		s = b;
		s += "";
		s = s + s;
		s += @"";
		s += "";
		OOStringDict d = "a 1";
		s = z[0];
		s = d["a"];
	}

	if ( allTests ) {
        NSLog( @"string slices" );

		OOStringDict d = "a 1 b 2 c 3", e( @"_", *d, nil );
		OOStringArray a( *d, nil ), b = d;
		OOString s = OOStringArray( d );
		assert( d[OOSlice("a b")]+OOStrs("4") == "1 2 4" );
		assert( d[OOSlice("a b")][1] == "2" );
		assert( d[OOSlice("a b")][OORange(1,2)] == "2" );
		//a[0] = d;
		assert( a[0][OOSlice("a b")]+OOStrs("4") == OOStrs( "1 2 4" ) );
		assert( a[0][OOSlice("a b")][1] == "2" );
		assert( a[0][OOSlice("a b")][OORange(1,2)] == "2" );
		a[1] = a[0][OOSlice("a b")];
		a[2] = a[0][OOSlice("a b")][OORange(1,2)];
		assert( e["_"][OOSlice("a b")]+OOStrs("4") == OOStrs( "1 2 4" ) );
		assert( e["_"][OOSlice("a b")][1] == "2" );
		assert( e["_"][OOSlice("a b")][OORange(1,2)] == "2" );
		e["_"] = d;
		assert( e["_"][OOSlice("a b")]+OOStrs("4") == OOStrs( "1 2 4" ) );
		assert( e["_"][OOSlice("a b")][1] == "2" );
		assert( e["_"][OOSlice("a b")][OORange(1,2)] == "2" );
	}

	if ( allTests ) {
        NSLog( @"regular expressions" );

		assert( (OOStr("a123 b123 B345")|@"/([ab])(\\d+)/$1=$2/i") == OOStr("a=123 b=123 B=345") );
		assert( OOStringArray( @"a", @"b", @"c", nil ) == (OOStr( "----a----b--c----") & "\\w+") );
		assert( OOStringArray( @"a", @"b", @"c", nil ) == (OOStr( "----a----b--c----") & "\\w+") );
		assert( OOStringArray( @"a", @"b", @"c", nil ) == (OOStr( "----a----b--c----") & "\\w+") );
		assert( OOStringArray( @"a", @"b", @"c", nil ) == (OOStr( "----a----b--c----") & "\\w+") );
		assert( OOStringArray( @"", @"a", @"b", @"c", @"", nil ) == (OOPattern( "-+" ).split( "-----a----b--c----")));
		assert( OOStringArray( @"a", @"b", @"c", nil ) == *(OOStr( "----a----b--c----") ^ "\\W+(\\w+)\\W+(\\w+)\\W+(\\w+)\\W+")[NSMakeRange(1,3)] );
		OOStringArray p = OOStr( "123abc" )^"(\\d+)(\\w+)(===)?";
		assert( !!p[2] );
		assert( *p[2] );
		assert( !p[3] );
		assert( !*p[3] );
		assert( !**p[3] );

        OOString str = @"hello,  world \n";
        OOStringArrayArray out = str[@"(\\w+)(,?\\s+(\\w+))"];
        assert( str[@"\\w+"][1] == @"world" );
        assert( (*out[0])[3] == @"world" );
        assert( (str-=@"\\s+$") == @"hello,  world" );
        assert( str/OOPattern(@",\\s+") == OOStringArray("hello world"));

        OOString str2 = kCFBundleNameKey;
        OOStringDict x;
        x[kCFBundleNameKey][kCFBundleNameKey];
        x[kCFBundleNameKey][0][kCFBundleNameKey];

        assert( (~str[@"(\\w)"])[1] == OOStringArray( "h" ) );
        assert( (~str[@"(\\w)"])[1] == OOStringArray( "e" ) );
        assert( (&str[@"\\w+"]).length == 3 );
#ifdef REG_ENHANCED
        assert( *str[@"(l)\\1"] == @"ll" );
        assert( *str[@"((\\w))\\1"] == @"ll" );
#endif
        const char *c[] = {"a", "b", NULL};
        OOStringDict d = c, e = d;
        assert( d[@"a"] == @"b" );

        OOString str3 = @"こんにちは";
        NSRange r = str3[@"にちは"];
        assert( r.location == 2 );
        assert( r.length == 3 );

        OOString input = @"abc";
        OOStringArray a = input[@"\\w"];
        assert( a == OOStringArray( "a b c" ) );
        a = input[@"\\w+"];
        assert( a == OOStringArray( "abc" ) );
        a = input[@"(\\w)"];
        assert( a == OOStringArray( "a b c" ) );
        a = input[@"(\\w(\\w)?)"];
        assert( a == OOStringArray( "ab c" ) );
        a = input[@"(\\w)(\\w+)"];
        assert( a == OOStringArray( "a bc" ) );
        input = @"a=1 b=222";
        a = input[@"(\\w)=(\\w+)"];
        assert( a == OOStringArray( "a 1 b 222") );
        OOStringDictionary d2 = a, d3 = input[@"(\\w)=(\\w+)"];
        assert( d2[@"b"] == "222" );
        assert( d3[@"a"] == "1" );
        d3 = input[@"(\\w)=(\\w+)"];
        assert( d3[@"b"] == "222" );
	}

	if ( allTests ) {
        NSLog( @"array references" );

		NSArray *x = nil;
		NSMutableArray *m = nil;
		OOReference<NSArray *> y = x, z = y;
		y = x;
		z = z;
		y <<= x;
		y <<= z;
		OOStringArray a = x, b = m;
		a = m;
		b = x;
		OOString s = @"1";
		s *= 3;
		assert( s == "111" );
		assert( s*2 == "111111" );
		//assert( s*0 == "" );
		OOStringArray q = "1 2";
		q *= 2;
		assert( q*2=="1 2 1 2 1 2 1 2" );
	}

	if ( allTests ) {
        NSLog( @"OONumber" );

		OONumber a = 22, b = a;
		assert( a+b == 44 );
		a += b;
		a = a/2.;
		OONumberDict d;
#ifndef __clang__
		d["a"] = a+b;
		d["a"] += 2;
		assert( d["a"] == 46. );
#endif
	}

	if (allTests ) {
        NSLog( @"dict ref compare" );

		OOStr a = "a", b = "b", c = "a";
		OOStrDict d;
		d["1"] = a;
		d["2"] = b;
		d["3"][0] = c;
		assert( a<b );
		assert( a==c );
		assert( d["2"]>d["1"] );
		assert( !(d["3"][0]!=*d["1"]) );
		assert( (d["3"][0]<=*d["1"]) );
		OOObjects<NSString *> var;
		var[99] = @"THIS";
		OOStrings ted;
		ted[99] <<= @"Go on ";
		ted[99] *= 10; 
	}

#ifndef OO_ARC
	if ( allTests ) {
		OOScan s( "123abc" );
		assert( !!(s & @"123") );
		assert( !(s & @"123") );
	}
#endif

	if ( allTests ) {
        NSLog( @"strict and ||" );

		OOReference<NSString *> a = (id)kCFNull;
		assert( !a );
		assert( a ? 1 : 0 );
		assert( !a );
		if ( a ) ; else assert( 0 );
		assert( a ? 1 : 0 );
		a = @"1";
		assert( a );
		OOReference<NSString *> b;
		assert( !b );
		////assert( b ? 1 : 0 );
		////assert( !!b );
		////assert( b ? 1 : 0 );
		b = @"1";
		assert( b );
		OOString c = "a", d;
		assert( (c || d) == "a" );
		assert( (d || c) == "a" );
		assert( (c || "b") == "a" );
		assert( (d || "b") == "b" );
	}

	if ( allTests ) {
        NSLog( @"slice tests" );

		OOStringArray strings = "a b c d";
		assert( strings[NSMakeRange(1,2)] == "b c" );
		strings[OORange(1,3)] = OOStringArray( "x y" );
		assert( strings == "a x y d" );

		OOStringDict dict = "a 1 b 2 c 3 d 4";
		assert( dict[OOSlice("b c")] == "2 3" );
		dict[OOSlice("b c")] = OOStringArray( "9 9" );
		assert( dict[OOSlice("b c")] == "9 9" );
	}

	if ( allTests ) {
        NSLog( @"string search" );

		OOString a = "1abc", a0 = "0abc", b;
		assert( a );
		assert( a ? 1 : 0 );
		assert( !a ? 0 : 1 );
		assert( a0 );
		assert( a0 ? 0 : 1 );
		assert( !a0 ? 0 : 1 );
		assert( !b );
		assert( b ? 0 : 1 );

        // where problematic...
		assert( a[@"a"] );
		assert( a[@"a"] ? 1 : 0 );
		assert( a[@"2"] == NSNotFound ? 1 : 0 );
		assert( a[@"1"] != NSNotFound ? 1 : 0 );
		assert( !a[@"1"] ? 0 : 1 );
		assert( !a[@"z"] );
		assert( a[@"z"] != NSNotFound ? 0 : 1 );
		assert( !b[@"z"] );
		/////assert( b[@"z"] != NSNotFound ? 0 : 1 );

        OOStringVars( a1, a2, a3 ) = a[@"\\w"];
        assert( a1 == @"1" );
        assert( a2 == @"a" );
        assert( a3 == @"b" );
#ifdef __clang__
        OOStringVars( b1, b2, b3 ) = @[@"2", @"a", @"b"];
        assert( b1 == @"2" );
        assert( b2 == @"a" );
        assert( b3 == @"b" );
#endif
        OOStringDict d = "a 1 b 2";
        OOStringVars( c1, c2, c3 ) = d[OOSlice("b a c")];
        assert( c1 == @"2" );
        assert( c2 == @"1" );
        assert( !c3 );
	}

    if ( allTests ) {
        OOString a = @"Block Test";
        a[@"(\\w)(\\w*)"] = ^( OOStringArray groups ) {
            return -*groups[1]+@"-"+(+*groups[2]);
        };
        assert( a == @"b-LOCK t-EST" );
    }

#if __MAC_OS_X_VERSION_MIN_REQUIRED  >= __MAC_10_7 \
|| __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_5_0
    if ( allTests ) {
        OOJson a = OOURL( @"http://zxapi.sinaapp.com/" ).data();
        int n = [*a[@"age"] intValue];
        assert( n == 23 );
        assert( a[@"girlFriends"][0]["friend"][@"girlName"] == @"I don't know" );
        NSLog( @"%@", *a );
    }
#endif

    if ( allTests && !memoryManaged && 01 ) {
        NSLog( @"objsql tests" );
        OOPool pool;

		[OODatabase exec:"drop table if exists PARENT_TABLE"];
		[OODatabase exec:"drop table if exists CHILD_TABLE"];

		// populate parent a child records
		for ( int i=0 ; i<10 ; i++ ) {
			ParentRecord *p = [ParentRecord new];
			p->ID = OO"ID"+i;
			p->c = 123*i;
			p->s = 234*i;
			p->i = 345*i;
			p->f = 456.*i;
			p->d = 567.*i;
			OO_RELEASE( [p insert] );
            ///NSLog( @"%@", *p->ID );
			for ( int j=0 ; j<i ; j++ ) {
				ChildRecord *c = [ChildRecord insertWithParent:p];
				for ( int k=0 ; k<2 ; k++ )
					c->strs += c->ID;
			}
			assert( [OODatabase commitTransaction] == 1+i );
		}
    
		// select using a record as a filter
		ParentRecord *filter = [ParentRecord record];
		filter->ID = "ID5";

		OOArray<ParentRecord *> sel1 = [filter select];
		assert( (int)sel1 == 1 );
		//OOPrint( sel1 );

		// test to-many relationship - "*" is required ///
		OOArray<ChildRecord *> sel2 = [*sel1[0] children];
		assert( (int)sel2 == 5 );
		assert( awoke == 5 );

		// check archived field
		ChildRecord *child = sel2[2];
		assert( child->strs == "ID5 ID5" );
		assert( [child parent]->ID == "ID5" );

		// test LIKE expression
		filter->ID = "ID%";
		sel1.fetch( filter, nil );
		assert( (int)sel1 == 10 );
	}
#ifndef OO_ARC
	assert( rcount == 0 ); 
#endif

	if ( allTests && useNetwork && !memoryManaged && 00 ) {
        NSLog( @"web requests" );

		assert( OOURL( "http://www.google.com" ).string() & "oogle" );
		OOString translate = OOURL( "http://translate.google.com/translate_t" ).post( "hl=en&ie=UTF-8&text=Hello&sl=en&tl=fr" );
		assert( translate & "Bonjour" );
		OOString inverse = OOURL( "http://translate.google.com/translate_t" ).post( "hl=en&ie=UTF-8&text=こんにちは&sl=ja&tl=en" );
		assert( inverse & "Hi" );
	}

	if ( allTests && useNetwork && 01 ) {
        NSLog( @"xml: %@", *OOString( OOResource( "test.xml" ).data(), NSISOLatin1StringEncoding ) );

		OONode xml = *OOResource( "test.xml" ).data();
		OONode orderID = xml[@"EXAMPLE"][@"ORDER"][@"HEADER"].node();
		OONode cust = orderID[0];
		assert( cust.text()  == "0000053535" );
		cust = xml[@"EXAMPLE"][@"ORDER"][@"HEADER"]["X_ORDER_ID"];
		assert( cust.text() == "0000053535" );
		cust = xml[@"EXAMPLE"][@"ORDER"][@"HEADER"]["X_ORDER_ID"][0];
		assert( cust.text() == "0000053535" );
		assert( xml[@"EXAMPLE/ORDER/HEADER/X_ORDER_ID"] == "0000053535" );
		assert( xml[@"EXAMPLE"][@"ORDER"][@"HEADER"][@"X_ORDER_ID"] == "0000053535" );
		assert( xml[@"EXAMPLE"][@"ORDER"][@"HEADER"][@"X_ORDER_ID"][0] == "0000053535" );
		assert( xml[@"EXAMPLE"][@"ORDER"][@"HEADER"][@"X_ORDER_ID"][0] == "0000053535" );
		assert( xml[@"EXAMPLE"][@"ORDER"][@"HEADER"][@"X_ORDER_ID"].node().text() == "0000053535" );
		assert( xml[@"EXAMPLE"]["ORDER"]["@lang"] == "de" );
		assert( xml[@"EXAMPLE"]["ORDER"]["@lang"] != "be" );
		assert( xml[@"EXAMPLE/ORDER/@lang"] == "de" );
		assert( xml[@"EXAMPLE/ORDER/@lang"] != "be" );
		assert( xml[@"EXAMPLE/ORDER/ENTRIES/ENTRY"][0]["ENTRY_NO"] == "10" );
		assert( xml[@"EXAMPLE/ORDER/ENTRIES/ENTRY"][1]["ENTRY_NO"] == "20" );
		OOString x = xml[@"EXAMPLE/ORDER/@lang"].text();
		//NSLog( @"%@", *x );
		//OONode x = xml[@"EXAMPLE"][@"ORDER"][@"HEADER"][@"X_ORDER_ID"][0].get();
		//assert( xml[@"EXAMPLE"][@"ORDER"][@"HEADER"][@"X_ORDER_ID"][0][0] == "0000053535" );
		////assert( xml[OOPath("EXAMPLE/ORDER/HEADER/CUSTOMER_ID")][0] == "1010" );
		////assert( xml[OOPath("EXAMPLE/ORDER")]["@lang"] == "de" );
		//OONodeArray entries = xml[OOPath("EXAMPLE/ORDER/ENTRIES")].children();
		//assert( (int)entries == 2 );
		OONodeArray entries_ = xml["EXAMPLE/ORDER/ENTRIES/ENTRY"].nodes();
		assert( (int)entries_ == 2 );
		entries_ = xml["EXAMPLE/ORDER/ENTRIES/ENTRY"];
		assert( (int)entries_ == 2 );
		assert( (int)xml["EXAMPLE/ORDER/ENTRIES/ENTRY"].nodes() == 2 );
		OONodeArray entries0 = xml["EXAMPLE/ORDER/ENTRIES"].children();
		assert( (int)entries0 == 2 );

		assert( xml["EXAMPLE/ORDER/ENTRIES/ENTRY/1/ENTRY_NO"] == "20" );
		assert( xml["EXAMPLE/ORDER/ENTRIES/ENTRY"].node(1)["ENTRY_NO"] == "20" );

		OOData d1 = xml;
		OONode n1 = *d1;
		assert( xml == n1 );

#if 1
		n1["john"]["change"] = "diff";
		n1["sam"] = "diff";
		n1["john/change"] = "diff";
		assert( xml != n1 );
		OONode n = OONode(), m = OONode( "m", "zzz" );
		n["a/b/c"] = "john";
#if 1
		n["a/b/e"] = "john";
		n["a/b/c/@d"] = "james";
		n["a/b/c/@a:b"] = "james";
		n["a/b/c/@xmlns"] = "http://a.b.c";
		n["a/b/c/@xmlns:x"] = "http://x.b.c";
		m["n"] = "x";
		n["a/b/c"] += m;
		m["n"] = "y";
		n["a/b/c"] += m;
		n["a/b/f"] = m;
		n["a/b/g/*"] = m;
        m["jjj"] = OO"a";
        m["jjsj"] = @"a";
        m["s"] = @"a";
        m["jsjssj"] = @"a";
        m["jsjsj"] = @"a";
		OOData d = n;
#endif

		//OONodeArray entries1 = xml[OOPath("EXAMPLE/ORDER/ENTRIES")][kOOChildren].get();
		//assert( (int)entries1 == 2 );
#if 1
		OONodeArray entries2 = xml[@"EXAMPLE"][@"ORDER"][@"ENTRIES"][@"ENTRY"].nodes();
		assert( (int)entries2 == 2 );
		OONodeArray entries3 = xml[@"EXAMPLE"][@"ORDER"][@"ENTRIES"][kOOChildren].get();
		assert( (int)entries3 == 2 );
#endif

#if 1
		int count = 30;
		NSString *iTunesUrl = OOFormat(@"http://ax.phobos.apple.com.edgesuite.net/WebObjects/MZStore.woa/wpa/MRSS/newreleases/limit=%d/rss.xml", count);
		NSData *iTunesData = &OOURL( iTunesUrl ).data();
		OONode top10 = iTunesData;
		OONodeArray items = (OONodeArray)top10["rss"]["channel"]["item"];
		assert( (int)items == count );
		OONodeArray items1 = top10["rss/channel/item"].nodes();
		assert( (int)items1 == count );

        if ( !memoryManaged ) {
		OOData i = top10;
		OOArray<iTunesItem *>itemArray = [OOMetaData import:items intoClass:[iTunesItem class]];
#if 0
		NSLog( @"XML: %@", *xml );
		NSLog( @"YYYYYYYYYY: %@  %@ %@", *m, *n, *OOString( (const char *)[*d bytes], [*d length] ) );
		NSLog( @"ZZZZZZZZZZ: %@", *OOString( (const char *)[i bytes], [i length] ) );
		NSString *iTunesRSS = [[[NSString alloc] initWithData:iTunesData encoding:NSUTF8StringEncoding] autorelease];
		NSLog( @"DATA: %x %x %@ %@ %@", iTunesRSS, [iTunesRSS copy], iTunesRSS, @"", *top10 );
		OOPrint( itemArray );
#endif
		OONode top11 = *i;
		assert( top11 == top10 );
        }
#endif
#endif
        ~m;
	}

    if ( allTests ) {
        NSLog( @"regexp" );
    
        OOString a = "john sam";
        OOStringArray b = a["\\w+"];
        assert( -b == "sam john" );
        assert( +-b == "john sam" );
        a["(\\w)(\\w)\\w+"] = "$1-$2";
        assert( a == "j-o s-a" );
        a["\\S+"] = OOStrs( "aa bb" );
        assert( a == "aa bb" );
        a["(\\w\\w)"] = "$1x$1";
        assert( a == "aaxaa bbxbb" );
        a["(aa)"] = OOStrs( @"$1", @"cc", nil );
        assert( a == "aaxcc bbxbb" );
        a["(x)"] = OOStrs( "y$1" );
        assert( a == "aayxcc bbxbb" );
    }

    if ( allTests ) {
        NSLog( @"blocks" );

        assert( (OOStrs("a b c")+'\'')/"-" == "'a'-'b'-'c'" );
    }

#if 0000
    if ( allTests && useNetwork ) {
        NSLog( @"soap" );
        OONode body( "TopGoalScorers" );
        body[@"@xmlns"] = @"http://footballpool.dataaccess.eu";
        body[@"iTopN"] = 5;
        OOSoap soap( @"http://footballpool.dataaccess.eu/data/info.wso" );
        OONode resp = soap.send( body, OOXMLRecursive );
        OONodeArray scorers = resp[@"Envelope/Body/TopGoalScorersResponse/TopGoalScorersResult/tTopGoalScorer"].nodes();
        assert( (int)scorers == 5 );
        scorers = resp[@"//tTopGoalScorer"];
        assert( (int)scorers == 5 );
        NSLog( @"%@", **scorers[0] );
    }
#endif

#if 1
	if ( allTests ) {
        NSLog( @"defaults" );

		OODefaults defaults;
		defaults[@"name"] = "value";
		defaults[@"run"] = (double)defaults[@"run"] + 1.;
	}

	if ( allTests ) {
		OODefaults defaults;
		assert( defaults[@"name"] == "value" );
	}

	// close/flush sqlite3 database
	[OODatabase sharedInstanceForPath:nil];
#endif

	[results setTitleWithMnemonic:@"All tests completed. OK"];
	[results setTextColor:[NSColor greenColor]];

	NSLog( @"%@", *("Tests complete "+OODefaults()[@"run"]) );

    //_objcpp.trace = YES;

#if 0
    {
        OORequest URL = OO"http://www.google.com";
        [self loadRequest:URL frame:@"_main_"];
        sleep(2);
    }
#endif

    threads--;
    if( [aNotification class] == [self class] )
        [self multithread:nil];
}

- (IBAction)multithread:cell {
    awoke = 0;
    memoryManaged = YES;
    [[[self class] new] performSelectorInBackground:@selector(applicationDidFinishLaunching:) withObject:self];
    [[[self class] new] performSelectorInBackground:@selector(applicationDidFinishLaunching:) withObject:self];
}

@end
